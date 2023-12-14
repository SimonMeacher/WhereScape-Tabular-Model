#--==============================================================================
#-- Script Name      :    export_templates.ps1
#-- Description      :    Unloads all templates scripts and procedures from a RED Repository
#-- Author           :    Tom Kelly, WhereScape
#--==============================================================================
#-- Notes / History
#-- TK  v 1.0.0 2018-07-24 First Version
#-- TK  v 2.0.0 2018-11-11 Now also handle scripts and procedures (not just templates)
#--

$gitProj = $PSScriptRoot

if([string]::IsNullOrEmpty($gitProj)) {
    Write-Output "Execute this script directly either from the console or with F5 from the ISE"
    Pause
}

$objectConfig = "$gitProj\objects_to_export.txt"
$connectConfig = "$gitProj\connect_info.txt"

if( ! (Test-Path $connectConfig) ) {
    $dsn = Read-Host -Prompt "DSN"
    $dsn | Set-Content $connectConfig
    
    $uid = Read-Host -Prompt "Username"
    if( ! [string]::IsNullOrWhiteSpace($uid)) {
        $uid | Add-Content $connectConfig

        $secPwd = Read-Host -Prompt "Password" -AsSecureString
        ConvertFrom-SecureString -SecureString $secPwd | Add-Content $connectConfig

    }

    Write-Output  "Connect information has been saved to '$connectConfig'"
    Write-Warning "You will not be prompted again"
    Write-Output  "Delete '$connectConfig' if you wish to be prompted for connection information"
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
if( ! [string]::IsNullOrWhiteSpace($pwd)) { $conn.ConnectionString += ";UID=$pwd" }

if( ! (Test-Path $objectConfig) ) {
    Write-Output "Enter full or partial names of templates, procedures and scripts you wish to export to file"
    Write-Output "wsl_%"
    Write-Output "other_*"
    Write-Output "another_template"
    $input = Read-Host -Prompt "Object Name"
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

$objectsToCommit = @(Get-Content $objectConfig | Where { ! [String]::IsNullOrWhiteSpace($_) })

$folders = @("Templates","Scripts","Procedures")

foreach($folder in $folders) {
    switch($folder) {
        "Templates" {
            $header_prefix = "th"
            $line_prefix = "tl"
            $ws_header_tab = "ws_tem_header"
            $ws_line_tab = "ws_tem_line"

            $file_extension = "peb"

            $type = "Template"
        }

        "Scripts" {
            $header_prefix = "sh"
            $line_prefix = "sl"
            $ws_header_tab = "ws_scr_header"
            $ws_line_tab = "ws_scr_line"

            $file_extension = "ps1"

            $type = "Script"
        }

        "Procedures" {
            $header_prefix = "ph"
            $line_prefix = "pl"
            $ws_header_tab = "ws_pro_header"
            $ws_line_tab = "ws_pro_line"

            $file_extension = "sql"

            $type = "Procedure"
        }
    }
    $sql = "SELECT ${header_prefix}_name as obj_name FROM $ws_header_tab"

    foreach($string in $objectsToCommit) {
        if($string -eq $objectsToCommit[0]) {
            $sql += " WHERE "
        }
        else {
            $sql += " OR "
        }
        $sql += "${header_prefix}_name LIKE '$string'"
    }

    $conn.Open()
    $dt = New-Object System.Data.DataTable
    $null = (New-Object System.Data.Odbc.OdbcDataAdapter($sql,$conn)).Fill($dt)
    $conn.Close()

    if( ! (Test-Path "${gitProj}\$folder")) {
        New-Item -ItemType Directory -Path "${gitProj}\$folder"
    }

    foreach ($object in $dt) {
    
        Write-Output "Exporting ${type}: $($object.obj_name)"

        try {

            $sw = New-Object System.IO.StreamWriter("${gitProj}\$folder\$($object.obj_name).${file_extension}",$false,(New-Object System.Text.UTF8Encoding($False)))
            $sw.AutoFlush = $true

            $query = "select replace(replace(${line_prefix}_line,char(10),''),char(13),'') 
                      from $ws_line_tab 
                      join $ws_header_tab 
                      on ${line_prefix}_obj_key = ${header_prefix}_obj_key 
                      where ${header_prefix}_name = '$($object.obj_name)'
                      order by ${line_prefix}_line_no"

            $conn.open()

            $reader = (New-Object System.Data.Odbc.OdbcCommand($query,$conn)).ExecuteReader()

            while ( $reader.Read() ) {
                $sw.WriteLine($reader.GetValue(0))
            }
    
        }
        catch {

            $host.ui.WriteErrorLine("Export of object '$($object.obj_name)' failed.")
            $host.ui.WriteErrorLine($_.Exception.Message)

        }
        finally {

            try { $sw.close() } catch {}
            try { $reader.close() } catch {}
            try { $conn.close() } catch {}

        }
    }
}

pause