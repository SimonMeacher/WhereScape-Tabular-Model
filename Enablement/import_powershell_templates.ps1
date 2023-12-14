param (
  [string]$metaDsn='',
  [string]$metaUser='',
  [string]$metaPwd=''
)

#--==============================================================================
#-- Script Name      :    install_templates.ps1
#-- Description      :    Load all templates scripts and procedures into a RED Repository
#-- Author           :    Tom Kelly, WhereScape
#--==============================================================================
#-- Notes / History
#-- TK  v 1.0.0 2018-07-24 First Version
#-- TK  v 2.0.0 2018-11-11 Now also handle scripts and procedures (not just templates)
#-- TK  v 3.0.0 2019-03-28 64 bit template and script support
#-- TK  v 4.0.0 2019-05-15 Better handling of upgrades
#-- MME v 5.0.0 2020-07-21 Enabled batch execution by cmdline parameters. Fallback connection for Scripts:'Runtime Connection for Scripts'

$gitProj = $PSScriptRoot

if([string]::IsNullOrEmpty($gitProj)) {
    Write-Output "Execute this script directly either from the console or with F5 from the ISE"
    Pause
}

$objectConfig = "$gitProj\objects_to_install.txt"
$connectConfig = "$gitProj\connect_info.txt"

if( ! (Test-Path $connectConfig) -or ! [string]::IsNullOrEmpty($metaDsn) ) {
    $dsn = if ([string]::IsNullOrEmpty($metaDsn)) { Read-Host -Prompt "Enter RED Metadata DSN" } else { $metaDsn }
    $dsn | Set-Content $connectConfig -Force
    
    $uid = if ([string]::IsNullOrEmpty($metaUser) -and [string]::IsNullOrEmpty($metaDsn)) { Read-Host -Prompt "Enter RED Username" } else { $metaUser }
    if( ! [string]::IsNullOrEmpty($uid)) {
        $uid | Add-Content $connectConfig
        if ([string]::IsNullOrEmpty($metaPwd)) { 
          $secPwd = Read-Host -Prompt "Enter Password" -AsSecureString
          $outFmt = ConvertFrom-SecureString -SecureString $secPwd
        } else {
          $secPwd = $metaPwd | ConvertTo-SecureString -AsPlainText -Force
          $outFmt = ConvertFrom-SecureString -SecureString $secPwd
        }
        $outFmt | Add-Content $connectConfig
    }

    Write-Output  "Connection information has been saved to '$connectConfig'"
    Write-Warning "You will not be prompted again"
    Write-Output  "Delete '$connectConfig' if you wish to be prompted for connection information"
	Write-Output  "OR overwrite the Connection information file by providing cmdline args"
}

$connInfo = @(Get-Content $connectConfig | Where { ! [String]::IsNullOrWhiteSpace($_) })

$dsn = $connInfo[0]
if($connInfo.Length -gt 1) {
    $uid = $connInfo[1]
    $secPwd = ConvertTo-SecureString $connInfo[2]
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPwd)
    $pwd = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
}

$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=$Dsn"
if( ! [string]::IsNullOrWhiteSpace($uid)) { $conn.ConnectionString += ";UID=$uid" }
if( ! [string]::IsNullOrWhiteSpace($pwd)) { $conn.ConnectionString += ";PWD=$pwd" }

if( ! (Test-Path $objectConfig) ) {
    Write-Output "Enter full or partial names of templates you wish to install"
    Write-Output "wsl_%"
    Write-Output "other_*"
    Write-Output "another_template"
    Write-Output "Templates must exist in '$gitProj\Templates'"
    $input = Read-Host -Prompt "Template Name"
    $input | Set-Content $objectConfig
    
    while ( ! [string]::IsNullOrWhiteSpace($input) ) {
        $input = Read-Host -Prompt "Template Name"
        if( ! [string]::IsNullOrWhiteSpace($input) ) {
            $input | Add-Content $objectConfig
        }
    }

    Write-Output  "Choices have been saved to '$objectConfig'"
    Write-Warning "You will not be prompted again"
    Write-Output  "Delete '$objectConfig' if you wish to be prompted for template names"
}

$objectsToInstall = @(Get-Content $objectConfig | Where { ! [String]::IsNullOrWhiteSpace($_) })

$conn.Open()

$folders = @("Templates","Scripts","Procedures")

foreach($folder in $folders) {

    switch ($folder) {

        "Templates" {
            $oo_type_key = 4
            $ws_header_tab = "ws_tem_header"
            $ws_line_tab = "ws_tem_line"

            $header_prefix = "th"
            $line_prefix = "tl"
        }

        "Scripts" {
            $oo_type_key = 3
            $ws_header_tab = "ws_scr_header"
            $ws_line_tab = "ws_scr_line"

            $header_prefix = "sh"
            $line_prefix = "sl"
        }

        "Procedures" {
            $oo_type_key = 1
            $ws_header_tab = "ws_pro_header"
            $ws_line_tab = "ws_pro_line"

            $header_prefix = "ph"
            $line_prefix = "pl"
        }
    }

    $ws_header_tab_v = $ws_header_tab + "_v"
    $ws_line_tab_v = $ws_line_tab + "_v"

    foreach($objectMatch in $objectsToInstall) {
        $objectMatch = $objectMatch.Replace('%','*')
        $objects = Get-ChildItem "$gitProj\$folder\$objectMatch"

        foreach($object in $objects) {

            try {

                $trans = $conn.BeginTransaction()

                $command = New-Object System.Data.Odbc.OdbcCommand
                $command.Connection = $conn
                $command.Transaction = $trans

                $objectName = $($object.Name.Split("."))[0]
                $objectPath = $object.FullName

                $ws_obj_object_ss1 = "SELECT count(oo_name) FROM dbo.ws_obj_object WHERE oo_name = '$objectName'"
                $command.CommandText = $ws_obj_object_ss1
                $ws_obj_object_sr1 = $command.ExecuteScalar()

                $exists = $false

                if($ws_obj_object_sr1 -gt 0) {
                    $ws_obj_object_ss2 = "SELECT count(oo_name) FROM dbo.ws_obj_object WHERE oo_name = '$objectName' AND oo_type_key = $oo_type_key"
                    $command.CommandText = $ws_obj_object_ss2
                    $ws_obj_object_sr2 = $command.ExecuteScalar()

                    if($ws_obj_object_sr2 -gt 0) {
                        $exists = $true
                    }
                    else {
                        Write-Warning "Object with name '$objectName' already exists but is a different object type. Skipping"
                        $trans.Rollback()
                        Continue
                    }
                }

                if($exists) {
                    switch($ws_header_tab) {
                        "ws_tem_header" {
                            Write-Output "Template with name '$objectName' already exists and will be versioned"
                        }
                        "ws_scr_header" {
                            Write-Output "Script with name '$objectName' already exists and will be versioned"
                        }
                        "ws_pro_header" {
                            Write-Output "Procedure with name '$objectName' already exists and will be versioned"
                        }

                    }

                    $ws_obj_object_ss4 = "SELECT oo_obj_key FROM ws_obj_object WHERE oo_name = '$objectName'"
                    $command.CommandText = $ws_obj_object_ss4
                    $ws_obj_object_sr4 = $command.ExecuteScalar()
                    $objectKey = $ws_obj_object_sr4

                    $ws_header_tab_v_ss1 = "SELECT coalesce(max(${header_prefix}_version_no),0) + 1 FROM $ws_header_tab_v"
                    $command.CommandText = $ws_header_tab_v_ss1
                    $ws_header_tab_v_sr1 = $command.ExecuteScalar()

                    $versionKey = $ws_header_tab_v_sr1

                    if ( $ws_header_tab -eq "ws_scr_header" ) {
                        $ws_header_tab_v_is1 = @"
                          INSERT INTO $ws_header_tab_v (
                              ${header_prefix}_version_no
                            , ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_purpose
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_status
                            , ${header_prefix}_script_language_key
                            , ${header_prefix}_connect_key
                          )
                          SELECT
                              $versionKey
                            , ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_purpose
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_status
                            , ${header_prefix}_script_language_key
                            , ${header_prefix}_connect_key
                          FROM $ws_header_tab
                          WHERE ${header_prefix}_name = '$objectName'
"@
                    }
                    elseif ( $ws_header_tab -eq "ws_tem_header" ) {
                        $ws_header_tab_v_is1 = @"
                          INSERT INTO $ws_header_tab_v (
                              ${header_prefix}_version_no
                            , ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_purpose
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_status
                            , ${header_prefix}_script_language_key
                          )
                          SELECT
                              $versionKey
                            , ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_purpose
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_status
                            , ${header_prefix}_script_language_key
                          FROM $ws_header_tab
                          WHERE ${header_prefix}_name = '$objectName'
"@
                    }
                    else {
                        $ws_header_tab_v_is1 = @"
                          INSERT INTO $ws_header_tab_v (
                              ${header_prefix}_version_no
                            , ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_purpose
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_status
                          )
                          SELECT
                              $versionKey
                            , ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_purpose
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_status
                          FROM $ws_header_tab
                          WHERE ${header_prefix}_name = '$objectName'
"@
                    }

                    $command.CommandText = $ws_header_tab_v_is1
                    $ws_header_tab_v_ir1 = $command.ExecuteNonQuery()

                    $ws_line_tab_v_is1 = @"
                      INSERT INTO $ws_line_tab_v ( 
                          ${line_prefix}_version_no
                        , ${line_prefix}_obj_key
                        , ${line_prefix}_line_no
                        , ${line_prefix}_line
                      )
                      SELECT
                          $versionKey
                        , ${line_prefix}_obj_key
                        , ${line_prefix}_line_no
                        , ${line_prefix}_line
                      FROM $ws_line_tab
                      JOIN $ws_header_tab
                      ON ${line_prefix}_obj_key = ${header_prefix}_obj_key
                      WHERE ${header_prefix}_name = '$objectName'
"@
                    $command.CommandText = $ws_line_tab_v_is1
                    $ws_line_tab_v_ir1 = $command.ExecuteNonQuery()

                    $ws_obj_versions_is1 = @"
                      INSERT INTO ws_obj_versions (
                          ov_version_no
                        , ov_obj_key
                        , ov_obj_name
                        , ov_obj_type_key
                        , ov_version_description
                        , ov_creation_date
                        , ov_retain_till_date
                        , ov_target_key
                      )
                      VALUES (
                          $versionKey
                        , $objectKey
                        , '$objectName'
                        , $oo_type_key
                        , 'Auto version on replace by template installer script'
                        , CURRENT_TIMESTAMP
                        , CAST(CAST(DATEADD(YEAR, 10, CURRENT_TIMESTAMP) AS DATE) AS DATETIME)
                        , 0
                      )
"@
                    $command.CommandText = $ws_obj_versions_is1
                    $ws_obj_versions_ir1 = $command.ExecuteNonQuery()

                    $ws_table_attributes_ds1 = "DELETE FROM ws_table_attributes WHERE ta_obj_key = ( SELECT ${header_prefix}_obj_key FROM $ws_header_tab WHERE ${header_prefix}_name = '$objectName' )"
                    $command.CommandText = $ws_table_attributes_ds1
                    $ws_table_attributes_dr1 = $command.ExecuteNonQuery()

                    $ws_line_tab_ds1 = "DELETE FROM $ws_line_tab WHERE ${line_prefix}_obj_key = ( SELECT ${header_prefix}_obj_key FROM $ws_header_tab WHERE ${header_prefix}_name = '$objectName' )"
                    $command.CommandText = $ws_line_tab_ds1
                    $ws_line_tab_dr1 = $command.ExecuteNonQuery()

                    $ws_header_tab_ds1 = "DELETE FROM $ws_header_tab WHERE ${header_prefix}_obj_key = ( SELECT ${header_prefix}_obj_key FROM $ws_header_tab WHERE ${header_prefix}_name = '$objectName' )"
                    $command.CommandText = $ws_header_tab_ds1
                    $ws_header_tab_dr1 = $command.ExecuteNonQuery()

                }
                
                Write-Output "Installing '$objectName'"

                $sw = [System.IO.File]::OpenText($objectPath)
                $header = $sw.ReadLine()
                $sw.Close()
                $header = $header.Replace("{# --","").Replace("-- #}","").Trim()
                $headConf = $header.Split(" ")
                try { $targetType = $headConf | Where { $_.IndexOf("TargetType:") -ne -1 } | ForEach-Object { $_.Replace("TargetType:","") } } catch {}

                switch ( $ws_header_tab ) {
                    "ws_tem_header" {

                        try { $templateType = $headConf | Where { $_.IndexOf("TemplateType:") -ne -1 } | ForEach-Object { $_.Replace("TemplateType:","") } } catch {}

                        if($targetType -eq "SQLServer") {
                            $ta_val_1 = 2
                        }
                        else {
                            $ta_val_1 = 13
                        }

                        if($templateType -eq "Alter") {
                            $th_type = "a"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "DDL") {
                            $th_type = "6"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Powershell") {
                            $th_type = "5"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Powershell32") {
                            $th_type = "5"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Powershell64") {
                            $th_type = "x"
                            $th_lang = "(SELECT sl_key FROM ws_script_language WHERE sl_name = 'PowerShell (64-bit)')" 
                        }
                        elseif($templateType -eq "Utility") {
                            $th_type = "7"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Unix") {
                            $th_type = "1"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Linux") {
                            $th_type = "1"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Windows") {
                            $th_type = "3"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "OLAP") {
                            $th_type = "2"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Block") {
                            $th_type = "8"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Procedure") {
                            $th_type = "9"
                            $th_lang = ""
                        }
                        else {
                            Write-Warning "Failed to extract template type from template header. Falling back to Powershell"
                            $th_type = "5"
                            $th_lang = ""
                        }
                    }

                    "ws_scr_header" {
                        
                        try { $templateType = $headConf | Where { $_.IndexOf("ScriptType:") -ne -1 } | ForEach-Object { $_.Replace("ScriptType:","") } } catch {}

                        if($templateType -eq "Powershell") {
                            $th_type = "P"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Powershell32") {
                            $th_type = "P" 
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Powershell64") {
                            $th_type = "X"
                            $th_lang = "(SELECT sl_key FROM ws_script_language WHERE sl_name = 'PowerShell (64-bit)')" 
                        }
                        elseif($templateType -eq "Windows") {
                            $th_type = "W"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Unix") {
                            $th_type = "U"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Linix") {
                            $th_type = "U"
                            $th_lang = ""
                        }
                        else {
                            Write-Warning "Failed to extract script type from header. Falling back to Powershell"
                            $th_type = "P"
                            $th_lang = ""
                        }

                        $script_conn_key_ss1 = @"
                          SELECT script_conn.dc_obj_key
                          FROM (
						  SELECT COALESCE (
                            ( SELECT TOP 1 CASE CHARINDEX('DefUpdateScriptCon',CAST(dc_attributes AS VARCHAR(4000)))
                                     WHEN 0 THEN NULL
                                     ELSE SUBSTRING(CAST(dc_attributes AS VARCHAR(4000)),CHARINDEX('DefUpdateScriptCon',CAST(dc_attributes AS VARCHAR(4000)))+25,CAST(SUBSTRING(CAST(dc_attributes AS VARCHAR(4000)),CHARINDEX('DefUpdateScriptCon',CAST(dc_attributes AS VARCHAR(4000))) + 20,4) AS INTEGER))
                                   END dc_name
                            FROM ws_dbc_connect  
                            WHERE dc_db_type_ind = 13 ),
							( select dc_name from ws_dbc_connect where dc_name = 'Runtime Connection for Scripts' ),
                            ( select dc_name from ws_dbc_connect where dc_name = 'Windows')
                          ) as script_conn_name
                          ) tgt_conn
                          JOIN ws_dbc_connect script_conn
                          ON script_conn.dc_name = tgt_conn.script_conn_name
"@
                        $command.CommandText = $script_conn_key_ss1
                        $script_conn_key = $command.ExecuteScalar()
                    }

                    "ws_pro_header" { 
                            
                        try { $templateType = $headConf | Where { $_.IndexOf("ProcedureType:") -ne -1 } | ForEach-Object { $_.Replace("ProcedureType:","") } } catch {}

                        if( $templateType -eq "Procedure" ) {
                            $th_type = "P"
                            $th_lang = ""
                        }
                        elseif( $templateType -eq "Trigger" ) {
                            $th_type = "P"
                            $th_lang = ""
                        }
                        elseif($templateType -eq "Block") {
                            $th_type = "B"
                            $th_lang = ""
                        }
                        else {
                            Write-Warning "Failed to extract procedure type from header. Falling back to Block"
                            $th_type = "B"
                            $th_lang = ""
                        }

                        $repo_conn_key_ss1 = @"
                          SELECT repo_conn.dc_obj_key
                          FROM ws_dbc_connect repo_conn
                          WHERE CHARINDEX('DataWarehouse', CAST(repo_conn.dc_attributes AS VARCHAR(4000))) <> 0
                          ORDER BY repo_conn.dc_obj_key
"@
                        $command.CommandText = $repo_conn_key_ss1
                        $repo_conn_key = $command.ExecuteScalar()
                        
                        $tgt_conn_key_ss1 = @"
                          SELECT tgt_conn.dc_obj_key
                          FROM ws_dbc_connect tgt_conn
                          WHERE tgt_conn.dc_db_type_ind = 13
                          ORDER BY tgt_conn.dc_obj_key
"@
                        $command.CommandText = $tgt_conn_key_ss1
                        $tgt_conn_key = $command.ExecuteScalar()
                    }
                }

                $ws_obj_object_ss1 = "SELECT count(oo_name) FROM dbo.ws_obj_object WHERE oo_name = '$objectName'"
                $command.CommandText = $ws_obj_object_ss1
                $ws_obj_object_sr1 = $command.ExecuteScalar()

                if($ws_obj_object_sr1 -lt 1) {

                    $ws_obj_object_is1 = @"
                      INSERT INTO ws_obj_object (
                          oo_name
                        , oo_type_key
                        , oo_group_key
                        , oo_project_key
                        , oo_active
                        , oo_target_key
                      )
                      VALUES (
                          '$objectName'
                        , $oo_type_key
                        , 0
                        , 0
                        , 'Y'
                        , 0
                      )
"@
                    $command.CommandText = $ws_obj_object_is1
                    $ws_obj_object_ir1 = $command.ExecuteNonQuery()
                }

                $ws_obj_object_ss3 = "SELECT oo_obj_key FROM ws_obj_object WHERE oo_name = '$objectName'"
                $command.CommandText = $ws_obj_object_ss3
                $ws_obj_object_sr3 = $command.ExecuteScalar()
                $objectKey = $ws_obj_object_sr3

                if ( $ws_header_tab -eq "ws_scr_header" ) {

                    if ( [string]::IsNullOrWhiteSpace($th_lang) ) {
                        $ws_header_tab_is1 = @"
                          INSERT INTO $ws_header_tab (
                              ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_connect_key
                          )
                          VALUES (
                              $objectKey
                            , '$objectName'
                            , '$th_type'
                            , CURRENT_TIMESTAMP
                            , CURRENT_TIMESTAMP
                            , 'WhereScape Ltd'
                            , 0
                            , CAST(NULLIF('$script_conn_key','') AS INTEGER)
                          )
"@
                    }
                    else {
                        $ws_header_tab_is1 = @"
                            INSERT INTO $ws_header_tab (
                              ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_script_language_key
                            , ${header_prefix}_connect_key
                            )
                            VALUES (
                              $objectKey
                            , '$objectName'
                            , '$th_type'
                            , CURRENT_TIMESTAMP
                            , CURRENT_TIMESTAMP
                            , 'WhereScape Ltd'
                            , 0
                            , $th_lang
                            , CAST(NULLIF('$script_conn_key','') AS INTEGER)
                            )
"@
                    }
                }
                elseif ( $ws_header_tab -eq "ws_pro_header" ) {
                    if ( [string]::IsNullOrWhiteSpace($th_lang) ) {
                        $ws_header_tab_is1 = @"
                            INSERT INTO $ws_header_tab (
                              ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_connect_key
                            )
                            VALUES (
                              $objectKey
                            , '$objectName'
                            , '$th_type'
                            , CURRENT_TIMESTAMP
                            , CURRENT_TIMESTAMP
                            , 'WhereScape Ltd'
                            , 0
                            , CASE CHARINDEX('trg_dim_col', '$objectName') WHEN 0 THEN CAST(NULLIF('$tgt_conn_key','') AS INTEGER) ELSE CAST(NULLIF('$repo_conn_key','') AS INTEGER) END
                            )
"@
                    }
                    else {
                        $ws_header_tab_is1 = @"
                            INSERT INTO $ws_header_tab (
                              ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_script_language_key
                            , ${header_prefix}_connect_key
                            )
                            VALUES (
                              $objectKey
                            , '$objectName'
                            , '$th_type'
                            , CURRENT_TIMESTAMP
                            , CURRENT_TIMESTAMP
                            , 'WhereScape Ltd'
                            , 0
                            , $th_lang
                            , CASE CHARINDEX('trg_dim_col', '$objectName') WHEN 0 THEN CAST(NULLIF('$tgt_conn_key','') AS INTEGER) ELSE CAST(NULLIF('$repo_conn_key','') AS INTEGER) END
                            )
"@
                    }
                }
                else {
                    if ( [string]::IsNullOrWhiteSpace($th_lang) ) {
                        $ws_header_tab_is1 = @"
                            INSERT INTO $ws_header_tab (
                              ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            )
                            VALUES (
                              $objectKey
                            , '$objectName'
                            , '$th_type'
                            , CURRENT_TIMESTAMP
                            , CURRENT_TIMESTAMP
                            , 'WhereScape Ltd'
                            , 0
                            )
"@
                    }
                    else {
                        $ws_header_tab_is1 = @"
                            INSERT INTO $ws_header_tab (
                              ${header_prefix}_obj_key
                            , ${header_prefix}_name
                            , ${header_prefix}_type
                            , ${header_prefix}_created
                            , ${header_prefix}_updated
                            , ${header_prefix}_author
                            , ${header_prefix}_user_key
                            , ${header_prefix}_script_language_key
                            )
                            VALUES (
                              $objectKey
                            , '$objectName'
                            , '$th_type'
                            , CURRENT_TIMESTAMP
                            , CURRENT_TIMESTAMP
                            , 'WhereScape Ltd'
                            , 0
                            , $th_lang
                            )
"@
                    }
                }

                $command.CommandText = $ws_header_tab_is1
                $ws_header_tab_ir1 = $command.ExecuteNonQuery()

                if( $ws_header_tab -eq "ws_tem_header") {

                    $ws_table_attributes_is1 = @"
                        INSERT INTO ws_table_attributes (
                            ta_obj_key
                        , ta_type
                        , ta_ind_1
                        , ta_val_1
                        )
                        VALUES (
                            $objectKey
                        , 'F'
                        , 'W'
                        , $ta_val_1
                        )
"@
                    $command.CommandText = $ws_table_attributes_is1
                    $ws_table_attributes_ir1 = $command.ExecuteNonQuery()
                }

                $sr = New-Object System.IO.StreamReader($objectPath)

                $lineNo = 0

                while( ! $sr.EndOfStream ) {
                    $lineNo ++
                    $objectLine = $sr.ReadLine()
                    $dbCompatible = "'" + $objectLine.Replace("'","''") + "'"

                    $ws_line_tab_is1 = @"
                      INSERT INTO $ws_line_tab (
                          ${line_prefix}_obj_key
                        , ${line_prefix}_line_no
                        , ${line_prefix}_line
                      )
                      VALUES (
                          $objectKey
                        , $lineNo
                        , $dbCompatible + CHAR(13)
                      )
"@
                    $command.CommandText = $ws_line_tab_is1
                    $ws_line_tab_ir1 = $command.ExecuteNonQuery()

                }

                $sr.Close()

                $ws_header_tab_us1 = "UPDATE $ws_header_tab SET ${header_prefix}_updated = CURRENT_TIMESTAMP WHERE ${header_prefix}_name = '$objectName'"
                $command.CommandText = $ws_header_tab_us1
                $ws_header_tab_ur1 = $command.ExecuteScalar()

                $trans.Commit()
            }
            catch {
                try { $trans.Rollback() } catch {}
                try { $sr.Dispose() } catch {}
                $host.ui.WriteErrorLine("Failed to install template '$objectName'")
                $host.ui.WriteErrorLine($_.Exception.Message)
                $host.ui.WriteErrorLine($_.InvocationInfo.PositionMessage)
            }
        }
    }
}
$conn.Close()

if ($error.count -gt 0) {
  Exit 1
} else {
  Exit $LASTEXITCODE
}