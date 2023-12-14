# --    (c) Wherescape Inc 2020. WhereScape Inc permits you to copy this Module solely for use with the RED software, and to modify this Module            -- #
# --    for the purposes of using that modified Module with the RED software, but does not permit copying or modification for any other purpose.           -- #
#==============================================================================
# Module Name      :    installer_target.psm1
# DBMS Name        :    Modules specific to Azure
# Description      :    Generic powershell functions module used for Azure installation,
#                       different templates, scripts and database specific
#                       modules
# Author           :    WhereScape Inc
#==============================================================================
# Notes / History

Function Set-GlobalVars {
  # TODO add function call that return the label from the License  
  $global:tgtLicenseLabel='Azure SQL DW' # Used in interactive prompts and help msgs
  $global:tgtTypeString='azdw' # Used in file name replcements such as "--tem-name "wsl_${tgtTypeSting}_${scriptType}_stage" "  
  # TODO parameterise these for Enterprise
  $global:tgtServer = "localhost"
  $global:tgtPort = 5432
  $global:metaServer = "localhost"
  $global:metaPort = 5432
}

Function Get-GeneralSetupCmds {
  $cmds=@"
"@
  return $cmds
}

Function Get-ConnectionSetupCmds {
  $cmds=@"
connection delete --force --name "Tutorial (OLTP)"
connection rename --force --new-name "Runtime Connection for Scripts" --old-name "windows"
connection modify --name "Runtime Connection for Scripts" --con-type "Windows" --odbc-source-arch 32 --work-dir $dstDir --default-load-type "Script based load" --default-load-script-template "wsl_${tgtTypeString}_${scriptType}_load"
connection add --name "$tgtDsn" --con-type "Database" --odbc-source "$tgtDsn" --odbc-source-arch $metaDsnArch --dtm-set-name "${tgtLicenseLabel} from ${tgtLicenseLabel}" --db-type Custom --def-update-script-con "Runtime Connection for Scripts" --def-pre-load-action "Truncate" --display-data-sql "SELECT TOP `$MAXDISPLAYDATA`$ * FROM `$OBJECT`$ " --row-count-sql "SELECT COUNT(*) FROM `$OBJECT`$" --drop-table-sql "DROP TABLE `$OBJECT`$" --drop-view-sql "DROP VIEW `$SCHEMA`$.`$TABLE`$" --truncate-sql "TRUNCATE TABLE `$OBJECT`$" --def-browser-schema "$($(@($tgtLoadSchema,$tgtStageSchema,$tgtEdwSchema,$tgtDvSchema) | Sort-Object | Get-Unique) -join ',')" --def-odbc-user Extract --def-table-alter-ddl-tem "wsl_${tgtTypeString}_alter_ddl" --def-table-create-ddl-tem "wsl_${tgtTypeString}_create_table" --def-view-create-ddl-tem "wsl_${tgtTypeString}_create_view" --con-info-proc "wsl_${tgtTypeString}_table_information" --extract-user-id "$tgtUser" --extract-pwd "$tgtPwd" --default-load-script-connection "Runtime Connection for Scripts" --default-load-script-template "wsl_${tgtTypeString}_${scriptType}_load" --default-load-type "Script based load"
target add --con-name "$tgtDsn" --name load --database "$tgtDB" --schema "$tgtLoadSchema" --tree-colour #ff0000
target add --con-name "$tgtDsn" --name stage --database "$tgtDB" --schema "$tgtStageSchema" --tree-colour #4e00c0
target add --con-name "$tgtDsn" --name edw --database "$tgtDB" --schema "$tgtEdwSchema" --tree-colour #008054
target add --con-name "$tgtDsn" --name data_vault --database "$tgtDB" --schema "$tgtDvSchema" --tree-colour #c08000
ext-prop-value modify --object-name "$tgtDsn" --value-data TRUE --value-name "DEBUG_MODE"
ext-prop-value modify --object-name "$tgtDsn" --value-data "FALSE" --value-name "SEND_FILES_ZIPPED"
ext-prop-value modify --object-name "$tgtDsn" --value-data "$azStorageAcc" --value-name "BLOB_ACCOUNT"
ext-prop-value modify --object-name "$tgtDsn" --value-data "$azAccessKey" --value-name "BLOB_KEY"
ext-prop-value modify --object-name "$tgtDsn" --value-data "$azStorageContainer" --value-name "BLOB_TEMP_CONTAINER"
ext-prop-value modify --object-name "$tgtDsn" --value-data "$azDS" --value-name "TEMP_DATA_SOURCE"
ext-prop-value modify --object-name "$tgtDsn" --value-data "RED_FMT_DEL_NOZIP_PIPE" --value-name "FILE_FORMAT"
ext-prop-value modify --object-name "$tgtDsn" --value-data "$azSQLDWConnString" --value-name "AZ_DF_TGT_CONN_STR"
ext-prop-value modify --object-name "$tgtDsn" --value-data | --value-name "AZ_UNLOAD_DELIMITER"
ext-prop-value modify --object-name "$tgtDsn" --value-data FALSE --value-name "AZ_UNICODE_SUPPORT"
ext-prop-value modify --object-name "$tgtDsn" --value-data 1 --value-name "AZ_SPLIT_COUNT"
ext-prop-value modify --object-name "$tgtDsn" --value-data 1000000 --value-name "AZ_SPLIT_THRESHOLD"
ext-prop-value modify --object-name "$tgtDsn" --value-data \" --value-name "AZ_UNLOAD_ENCLOSED_BY"
ext-prop-value modify --object-name "$tgtDsn" --value-data # --value-name "AZ_UNLOAD_ESCAPE_CHAR"
connection add --name "Database Source System" --con-type ODBC --odbc-source "SET THIS VALUE" --odbc-source-arch $metaDsnArch --work-dir $dstDir --db-type "SQL Server" --dtm-set-name "${tgtLicenseLabel} from SQL Server" --def-pre-load-action "Truncate" --def-browser-schema "SET THIS VALUE" --def-odbc-user Extract --default-load-script-connection "Runtime Connection for Scripts" --default-load-script-template "wsl_${tgtTypeString}_${scriptType}_load" --default-load-type "Script based load"
connection add --name "Windows Comma Sep Files" --con-type Windows --work-dir $dstDir --dtm-set-name "${tgtLicenseLabel} from File" --default-load-type "Script based load" --default-load-script-template "wsl_${tgtTypeString}_${scriptType}_load"
ext-prop-value modify --object-name "Windows Comma Sep Files" --value-data "RED_FMT_DEL_NOZIP_COMMA" --value-name "FILE_FORMAT"
connection add --name "Windows Pipe Sep Files" --con-type Windows --work-dir $dstDir --dtm-set-name "${tgtLicenseLabel} from File" --default-load-type "Script based load" --default-load-script-template "wsl_${tgtTypeString}_${scriptType}_load"
ext-prop-value modify --object-name "Windows Pipe Sep Files" --value-data "RED_FMT_DEL_NOZIP_PIPE" --value-name "FILE_FORMAT"
"@
  if ($metaType -eq 'SQL') {
    $cmds += "`r`n" + @"
connection rename --force --new-name Repository --old-name "DataWarehouse"
connection modify --name "Repository" --con-type Database --db-id "$metaBase" --odbc-source "$metaDsn" --odbc-source-arch $metaDsnArch --work-dir $dstDir --db-type "SQL Server" --meta-repo true --function-set "AZURE" --def-browser-schema "dbo" --def-odbc-user Extract --extract-user-id "$metaUser" --extract-pwd "$metaPwd" 
"@
  } 
  else {
    $cmds += "`r`n" + @"
connection modify --name "Repository" --con-type Database --db-id "$metaBase" --odbc-source "$metaDsn" --odbc-source-arch $metaDsnArch --work-dir $dstDir --db-type "PostgreSQL" --meta-repo true --function-set "AZURE" --def-browser-schema "red" --def-odbc-user Extract --extract-user-id "$metaUser" --extract-pwd "$metaPwd" --db-server "$metaServer" --db-port "$metaPort" --default-load-script-connection "Runtime Connection for Scripts" 
"@  
  }
  return $cmds
}

Function Get-SetDefaultTemplateCmds {
  $cmds=@"
connection set-default-template --con-name "$tgtDsn" --obj-type "Stage" --obj-sub-type "Stage" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_stage"
connection set-default-template --con-name "$tgtDsn" --obj-type "Stage" --obj-sub-type "DataVaultStage" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_dv_stage"
connection set-default-template --con-name "$tgtDsn" --obj-type "Stage" --obj-sub-type "WorkTable" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_stage"
connection set-default-template --con-name "$tgtDsn" --obj-type "ods" --obj-sub-type "DataStore" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "ods" --obj-sub-type "History" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_hist"
connection set-default-template --con-name "$tgtDsn" --obj-type "HUB" --obj-sub-type "Detail" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_dv_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Link" --obj-sub-type "Detail" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_dv_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Satellite" --obj-sub-type "History" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_dv_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Normal" --obj-sub-type "Normalized" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Normal" --obj-sub-type "History" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_hist"
connection set-default-template --con-name "$tgtDsn" --obj-type "Dim" --obj-sub-type "ChangingDimension" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_hist"
connection set-default-template --con-name "$tgtDsn" --obj-type "Dim" --obj-sub-type "Dimension" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Dim" --obj-sub-type "PreviousDimension" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Dim" --obj-sub-type "RangedDimension" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Dim" --obj-sub-type "TimeDimension" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Dim" --obj-sub-type "MappingTable" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Dim" --obj-sub-type "WorkTable" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Fact" --obj-sub-type "Detail" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Agg" --obj-sub-type "Aggregate" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Agg" --obj-sub-type "Summary" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Agg" --obj-sub-type "WorkTable" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
connection set-default-template --con-name "$tgtDsn" --obj-type "Custom2" --obj-sub-type "Detail" --op-type "UpdateRoutine" --tem-name "wsl_${tgtTypeString}_${scriptType}_perm"
"@
  return $cmds
}

Function Get-ApplicationDeploymentCmds ($applicationBaseDir){
  # RED Application deployments
  if ($metaType -eq 'SQL') {
    $cmds = @"
deployment deploy --app-number dim_date --app-version 20190512 --app-directory "$applicationBaseDir\$metaType\Date Dimension" --continue-ver-mismatch --default-load-script-connection "Runtime Connection for Scripts" --dest-connection-name "$tgtDsn" --dest-target-name "load"
deployment deploy --app-number AZFILEFMT --app-version 0001 --app-directory "$applicationBaseDir\$metaType\File Formats" --continue-ver-mismatch --default-load-script-connection "Runtime Connection for Scripts" --dest-connection-name "$tgtDsn" --dest-target-name "load"
"@
  }
  else {
    $cmds = @"
deployment deploy --app-number dim_date --app-version 20200311 --app-dir "$applicationBaseDir\$metaType\Date Dimension" --continue-ver-mismatch --def-load-script-con "Runtime Connection for Scripts" --dest-con-name "$tgtDsn" --dest-tgt-name "load"
"@  
  }
  return $cmds
}

# Print script help msg
Function Print-Help {
  $helpMsg = @"

This WhereScape Enablement Pack install script must be run as administrator.

Prerequisites before running this script: 
  1. Valid install of WhereScape RED with License key entered and accepted
  2. An empty SQL Server Database with a DSN to connect to it
  3. An empty Azure Database with a DSN to connect to it
   - Your Azure DB should have at least one dedicated schema available for use in creating RED Data Warehouse Targets
   - Azure ODBC Driver installed

Any required parameters will be prompted for at run-time, otherwise enter each named paramter as arguments:  

Example:.\install_New_RED_Repository.ps1 -metaDsn "REDMetaRepoDSN" -metaUser "REDMetaRepoUser" -metaPwd "REDMetaRepoPwd" -metaBase "REDMetaRepoDB" -tgtDB "${tgtTypeString}DB" -tgtLoadSchema "dev_load" -tgtStageSchema "dev_stage" -tgtEdwSchema "dev_edw" -tgtDvSchema "dev_dv" -tgtDsn "${tgtTypeString}Dsn" -tgtUser "${tgtTypeString}User" -tgtPwd "${tgtTypeString}Pwd" -templateSet "powershell" -azStorageAcc "AzureStorageAccount" -azAccessKey "AzureAccessKey" -azStorageContainer "AzureStorageContainer" -azDS "AzureDS" -azSQLDWConnString "AzureSQLDWConnString"

Available Parameters:
  -help                   "Displays this help message"
  -metaDsn                "RED MetaRepo DSN"                         [REQUIRED]
  -metaDsnArch            "64 or 32"                                 [DEFAULT = 64]
  -metaUser               "RED MetaRepo User"                        [OMITTED FOR WINDOWS AUTH]
  -metaPwd                "RED MetaRepo PW"                          [OMITTED FOR WINDOWS AUTH]
  -metaBase               "RED MetaRepo DB"                          [REQUIRED]
  -tgtDB                  "Azure DB"                                 [REQUIRED]
  -tgtLoadSchema          "Azure Load Target Schema"                 [REQUIRED]
  -tgtStageSchema         "Azure Stage Target Schema"                [REQUIRED]
  -tgtEdwSchema           "Azure Load Target Schema"                 [REQUIRED]
  -tgtDvSchema            "Azure Load Target Schema"                 [REQUIRED]
  -tgtDsn                 "Azure DSN"                                [REQUIRED]
  -tgtUser                "Azure User"                               [OMITTED FOR WINDOWS AUTH]
  -tgtPwd                 "Azure Password"                           [OMITTED FOR WINDOWS AUTH]
  -templateSet            "PowerShell"                               [DEFAULT=PowerShell]
  -azStorageAcc           "Azure Storage Account"                    [DEFAULT="<Enter Azure Storage Account>"]
  -azAccessKey            "Azure Access Key"                         [DEFAULT=""]
  -azStorageContainer     "Azure Storage Container"                  [DEFAULT="<Enter Azure Storage Container>"]
  -azDS                   "Azure Data Source"                        [DEFAULT="<Enter Azure Data Source>"]
  -azSQLDWConnString      "Azure SQL DW Connection String"           [DEFAULT="<Enter ${tgtLicenseLabel} Connection String>"]
  -startAtStep            "Defaults to first step, used to resume script from a certain step" [DEFAULT = 1]
"@
  Write-Host $helpMsg
}

Function Get-ScriptParamters ( $boundParameters = $PSBoundParameters, $cmdArgs = $Args ) {
  # Validate Script Parameters
  if ( $help -or $unmatchedParams ) {
    Print-Help 
    Exit
  } 
  else {
    # Prompt for any required paramaters
    if([string]::IsNullOrEmpty($tgtDsn))            {$global:tgtDsn = Read-Host -Prompt "Enter ${tgtLicenseLabel}  DSN"}
    if($boundParameters.count -eq 0 -or ($boundParameters.ContainsKey('startAtStep') -and $boundParameters.count -eq 1)) {
      $global:tgtUser = Read-Host -Prompt "Enter ${tgtLicenseLabel} User or 'enter' for none"
    }
    if(![string]::IsNullOrEmpty($tgtUser) -and [string]::IsNullOrEmpty($tgtPwd) ) {
      $tgtPwdSecureString = Read-Host -Prompt "Enter ${tgtLicenseLabel}  Pwd" -AsSecureString
      $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tgtPwdSecureString)
      $global:tgtPwd = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    if([string]::IsNullOrEmpty($tgtDB))                   {$global:tgtDB = Read-Host -Prompt "Enter ${tgtLicenseLabel}  DB"}
    if([string]::IsNullOrEmpty($tgtLoadSchema))           {$global:tgtLoadSchema = Read-Host -Prompt "Enter ${tgtLicenseLabel} Target 'Load' Schema (the vaule entered will be the default for following schemas)" | %{if([string]::IsNullOrEmpty($_)){'DEV_LOAD'}else{$_}} }
    if([string]::IsNullOrEmpty($tgtStageSchema))          {$global:tgtStageSchema = Read-Host -Prompt "Enter ${tgtLicenseLabel} Target 'Stage' Schema, default: '$tgtLoadSchema'" | %{if([string]::IsNullOrEmpty($_)){$tgtLoadSchema}else{$_}} }
    if([string]::IsNullOrEmpty($tgtEdwSchema))            {$global:tgtEdwSchema = Read-Host -Prompt "Enter ${tgtLicenseLabel} Target 'EDW' Schema, default: '$tgtLoadSchema'" | %{if([string]::IsNullOrEmpty($_)){$tgtLoadSchema}else{$_}} }
    if([string]::IsNullOrEmpty($tgtDvSchema))             {$global:tgtDvSchema = Read-Host -Prompt "Enter ${tgtLicenseLabel} Target 'Data Vault' Schema, default: '$tgtLoadSchema'" | %{if([string]::IsNullOrEmpty($_)){$tgtLoadSchema}else{$_}} }

    # Target specific paramters are defaulted
	if ($templateSet -notin 'Powershell')            {$global:templateSet = 'Powershell'}     
    $global:targetCmdLineArgs += " -templateSet `"$templateSet`""
	if([string]::IsNullOrEmpty($azStorageAcc))            {$global:azStorageAcc = "<Enter Azure Storage Account Name>"}
	$global:targetCmdLineArgs += " -azStorageAcc `"$azStorageAcc`""
	if([string]::IsNullOrEmpty($azAccessKey))            {$global:azAccessKey = ""}
	$global:targetCmdLineArgs += " -azAccessKey `"`""
	if([string]::IsNullOrEmpty($azStorageContainer))            {$global:azStorageContainer = "<Enter Azure Storage Container Name>"}
	$global:targetCmdLineArgs += " -azStorageContainer `"$azStorageContainer`""
	if([string]::IsNullOrEmpty($azSQLDWConnString))            {$global:azSQLDWConnString = "<Enter ${tgtLicenseLabel} Connection String>"}
	$global:targetCmdLineArgs += " -azSQLDWConnString `"$azSQLDWConnString`""
	if([string]::IsNullOrEmpty($azDS))            {$global:azDS = "<Enter Azure External Data Source Name>"}
	$global:targetCmdLineArgs += " -azDS `"$azDS`""
	
  }
}

Function Execute-PreSteps {
  # specific pre steps for this target type
  if ($installStep -ge $startAtStep) {
  }
}

Function Execute-PostSteps {
  # specific post steps for this target type
  if ($installStep -ge $startAtStep) {
		$tgtSnowsqlAcc=""
		$sql = @"
-- set default Export template 
MERGE INTO ws_dbc_default_template AS dt
USING (select oo_obj_key from dbo.ws_obj_object where oo_name = '$tgtDsn') AS new_dt
      ON dt.ddt_connect_key = new_dt.oo_obj_key AND dt.ddt_table_type_key = 13  
WHEN MATCHED THEN 
UPDATE SET dt.ddt_connect_key = (select oo_obj_key from dbo.ws_obj_object where oo_name = '$tgtDsn'),
           dt.ddt_table_type_key = 13,
           dt.ddt_template_key = (select oo_obj_key from dbo.ws_obj_object where oo_name = 'wsl_${tgtTypeString}_${scriptType}_export' and oo_type_key = 4),
           ddt_operation_type = 5
WHEN NOT MATCHED THEN
INSERT (ddt_connect_key, ddt_table_type_key,ddt_template_key,ddt_operation_type) 
VALUES ((select oo_obj_key from dbo.ws_obj_object where oo_name = '$tgtDsn'),13,(select oo_obj_key from dbo.ws_obj_object where oo_name = 'wsl_${tgtTypeString}_${scriptType}_export' and oo_type_key = 4),5)
;
"@
   Execute-SQL-Block $sql
  }
}