param (
  $unmatchedParameter,
  [switch]$help=$false,
  [string]$metaDsn,
  [string]$metaDsnArch='64',
  [string]$metaUser='',
  [string]$metaPwd='',
  [string]$metaBase,
  [string]$snowflakeConnectionName,
  [string]$templateSet='Powershell',
  [int]$startAtStep=1
)

#--==============================================================================
#-- Script Name      :    set_default_templates.ps1
#-- Description      :    Sets or Updates the Default Templates on Connections
#-- Author           :    WhereScape Inc
#--==============================================================================
#-- Notes / History
#-- MME v 1.0.0 2020-07-21 First Version

# Print script help msg
Function Print-Help {
  $helpMsg = @"

This script updates the RED Connection level default templates.

Prerequisites before running this script: 
  1. A Valid WhereScape RED metadata repository including a Snowflake Target Connection
  2. The full set of WhereScape provided Python OR Powershell Templates must already be installed
    - For Ptyon run .\install_python_templates.ps1 to apply these templates to your repository
    - For Powershell run .\install_powershell_templates.ps1 to apply these templates to your repository

Any required parameters will be prompted for at run-time, otherwise enter each named parameter as arguments:  

Example:.\set_default_templates.ps1 -metaDsn "REDMetaRepoDSN" -metaUser "REDMetaRepoUser" -metaPwd "REDMetaRepoPwd" -metaBase "REDMetaRepoDB" -snowflakeConnectionName "snowflakeConnectionName" -templateSet "Powershell" -startAtStep 1

Available Parameters:
  -help                       "Displays this help message"
  -metaDsn                    "RED MetaRepo DSN"                  [REQUIRED]
  -metaDsnArch                "64 or 32"                          [DEFAULT = 64]
  -metaUser                   "RED MetaRepo User"                 [OMITTED FOR WINDOWS AUTH]
  -metaPwd                    "RED MetaRepo PW"                   [OMITTED FOR WINDOWS AUTH]
  -metaBase                   "RED MetaRepo DB"                   [REQUIRED]
  -azureConnectionName        "Azure Connection Name in RED"      [REQUIRED]
  -templateSet                "Powershell or Python"              [DEFAULT = Powershell]
  -startAtStep                "Defaults to first step, used to resume script from a certain step" [DEFAULT = 1]
"@
  Write-Host $helpMsg
}

# Validate Script Parameters
if ( $help -or $unmatchedParameter -or ( $Args.Count -gt 0 )) {
  Print-Help 
  Exit
} 
else {
  # Prompt for any required paramaters
  if([string]::IsNullOrEmpty($metaDsn))                 {$metaDsn = Read-Host -Prompt "Enter RED MetaRepo DSN"}
  if($PSBoundParameters.count -eq 0)                    {$metaUser = Read-Host -Prompt "Enter RED MetaRepo User or 'enter' for none"}
  if(![string]::IsNullOrEmpty($metaUser) -and [string]::IsNullOrEmpty($metaPwd)) {
    $metaPwdSecureString = Read-Host -Prompt "Enter RED MetaRepo Pwd" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($metaPwdSecureString)
    $metaPwd = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  }
  if([string]::IsNullOrEmpty($metaBase))                {$metaBase = Read-Host -Prompt "Enter RED MetaRepo DB"}
  if([string]::IsNullOrEmpty($azureConnectionName)) {$azureConnectionName = Read-Host -Prompt "Enter Azure Synapse Connection Name in RED (For E.g Azure DW Warehouse )"}
  #if($PSBoundParameters.count -eq 0)  {$templateSet = Read-Host -Prompt "Enter the template set to apply defaults for, either 'Powershell' (default) or 'Python'"}
  #if ($templateSet -notin 'Powershell','Python') {
    #Write-Warning "-templateSet not set or invalid defaulting to 'Powershell'"
    $templateSet = 'Powershell'
  #}
  # Output the command line used to the host (passwords replced with '***')
  Write-Host "`nINFO: Run Parameters: -metaDsn '$metaDsn' -metaDsnArch '$metaDsnArch' $( if(![string]::IsNullOrEmpty($metaUser)){"-metaUser '$metaUser' -metaPwd '***' "})-metaBase '$metaBase' -azureConnectionName '$azureConnectionName' -templateSet '$templateSet' -startAtStep $startAtStep`n"
}


$logLevel=5
$outputMode='json'
$scriptType='pscript'
if ($templateSet -eq 'Python') {
  $scriptType='pyscript'
}

# Print the starting step
if ($startAtStep -ne 1) { Write-Host "Starting from Step = $startAtStep" }

# Check for a correct RED Version
$redLoc="C:\Program Files\WhereScape\RED\"
$getRedVersion = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName, DisplayVersion, InstallLocation | where DisplayName -eq "WhereScape RED" | where DisplayVersion -ge "8.5.*"
if ($getRedVersion -isnot [array] -and $getRedVersion -ne $null) { 
  $redLoc = $getRedVersion.InstallLocation 
} elseif ($getRedVersion.count -gt 1) {
  Write-Warning "Multiple RED Versions available, please select one from:"
  $getRedVersion | %{ write-host $_.InstallLocation }
  $redLoc = Read-Host -Prompt "Please Enter a RED Install Directory from the above list"
} else {
  Write-Warning "Could not find a compatible RED Version Installed - Please install WhereScape RED 8.5.1.0 or greater to continue."
  Exit
}

# Build required file and folder paths
$redCliPath=Join-Path -Path $redLoc -ChildPath "RedCli.exe"

# common RedCli arguments
$commonRedCliArgs = @" 
--meta-dsn "$metaDsn" --meta-dsn-arch "$metaDsnArch" --meta-user-name "$metaUser" --meta-password "$metaPwd" --meta-database "$metaBase" --log-level "$logLevel" --output-mode "$outputMode"
"@

$pyDefTempSetupCmds=@"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Stage" --obj-sub-type "Stage" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_stage"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Stage" --obj-sub-type "DataVaultStage" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_dv_stage"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Stage" --obj-sub-type "WorkTable" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_stage"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "ods" --obj-sub-type "DataStore" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "ods" --obj-sub-type "History" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_hist"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "HUB" --obj-sub-type "Detail" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_dv_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Link" --obj-sub-type "Detail" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_dv_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Satellite" --obj-sub-type "History" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_dv_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Normal" --obj-sub-type "Normalized" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Normal" --obj-sub-type "History" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_hist"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Dim" --obj-sub-type "ChangingDimension" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_hist"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Dim" --obj-sub-type "Dimension" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Dim" --obj-sub-type "PreviousDimension" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Dim" --obj-sub-type "RangedDimension" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Dim" --obj-sub-type "TimeDimension" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Dim" --obj-sub-type "MappingTable" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Dim" --obj-sub-type "WorkTable" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Fact" --obj-sub-type "Detail" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_dv_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Agg" --obj-sub-type "Aggregate" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_dv_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Agg" --obj-sub-type "Summary" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_dv_perm"
connection set-default-template --connection-name "$azureConnectionName" --obj-type "Agg" --obj-sub-type "WorkTable" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_dv_perm"
#connection set-default-template --connection-name "$azureConnectionName" --obj-type "Custom2" --obj-sub-type "Detail" --op-type "UpdateRoutine" --template-name "wsl_azdw_${scriptType}_perm"
"@

Function Remove-Passwords ($stringWithPwds) { 
  $stringWithPwdsRemoved = $stringWithPwds
  if (![string]::IsNullOrEmpty($metaPwd)){ 
    $stringWithPwdsRemoved = $stringWithPwdsRemoved -replace "(`"|`'| ){1}$metaPwd(`"|`'| |$){1}",'$1***$2'
  } 
  $stringWithPwdsRemoved 
}

Function Execute-Command ($commandTitle, $commandPath, $commandArguments)
{
    Try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $commandPath
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.WindowStyle = 'Hidden'
        $pinfo.CreateNoWindow = $True
        $pinfo.Arguments = $commandArguments
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        $p | Add-Member "commandTitle" $commandTitle
        $p | Add-Member "stdout" $stdout
        $p | Add-Member "stderr" $stderr
    }
    Catch {
    }
    $p
}

Function Execute-RedCli-Command ( $commandArguments, $commonArguments="" ) {
  $cmdReturn = Execute-Command "RedCli CMD" $redCliPath "$commandArguments $commonArguments"
  $progressEnd = ($cmdReturn.stdout -split "`n" | Select-String -Pattern ',"Progress End":.+"}').Line
  if ($cmdReturn.stderr.Trim() -ne '' -or $progressEnd -notmatch 'Error Message":"","Progress End"') {
      Write-Output "Failure executing cmd: $(Remove-Passwords $commandArguments)"
      Write-Output "Failed at step = $installStep"
      if ($cmdReturn.stderr.Trim() -ne '') { Write-Output $cmdReturn.stderr }
      Write-Output $( $progressEnd -replace '.+?"Progress End":".+?\}(.+?)','$1' )
      Exit
  }
  else {
      $batchJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '^{"Batch":\[').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
      $cmdResult = ($batchJson | ConvertFrom-Json).Batch[0].Result
      Write-Output "Result: $cmdResult Cmd: $(Remove-Passwords $commandArguments)"
  }
}


# ---------------------------------------------------------------------------------------------------
# 
#             MAIN SETUP BEGINS
#
# ---------------------------------------------------------------------------------------------------

# Run Python setup commands
$installStep=100
$cmdArray = $pyDefTempSetupCmds.replace("`r`n", "`n").split("`n")  
for($i=0; $i -lt $cmdArray.Count; $i++) {
  $global:installStep++
  if ($installStep -ge $startAtStep) {
    Execute-RedCli-Command $cmdArray[$i] $commonRedCliArgs
  }
}

#Update with SQL Commands
$installStep=200
if ($installStep -ge $startAtStep) {
  $sql = @"
MERGE INTO ws_dbc_default_template AS dt
USING (select oo_obj_key from dbo.ws_obj_object where oo_name = '$azureConnectionName') AS new_dt
      ON dt.ddt_connect_key = new_dt.oo_obj_key AND dt.ddt_table_type_key = 13  
WHEN MATCHED THEN 
UPDATE SET dt.ddt_connect_key = (select oo_obj_key from dbo.ws_obj_object where oo_name = '$azureConnectionName'),
           dt.ddt_table_type_key = 13,
           dt.ddt_template_key = (select oo_obj_key from dbo.ws_obj_object where oo_name = 'wsl_azdw_${scriptType}_export' and oo_type_key = 4),
           ddt_operation_type = 5
WHEN NOT MATCHED THEN
INSERT (ddt_connect_key, ddt_table_type_key,ddt_template_key,ddt_operation_type) 
VALUES ((select oo_obj_key from dbo.ws_obj_object where oo_name = '$azureConnectionName'),13,(select oo_obj_key from dbo.ws_obj_object where oo_name = 'wsl_azdw_${scriptType}_export' and oo_type_key = 4),5)
;
UPDATE dbo.ws_table_attributes 
SET ta_ind_1 = 4, 
    ta_val_1 = (select oo_obj_key from dbo.ws_obj_object where oo_name = 'wsl_azdw_${scriptType}_load' and oo_type_key = 4)
WHERE ta_obj_key IN (
    select oo_obj_key from dbo.ws_obj_object where oo_name in ('Database Source System','Runtime Connection for Scripts','Windows Comma Sep Files','Windows Fixed Width','Windows JSON Files','Windows Pipe Sep Files','Windows XML Files') 
  )
AND ta_type = 'L'
;
UPDATE dbo.ws_table_attributes 
SET ta_val_2 = (select oo_obj_key from dbo.ws_obj_object where oo_name = 'wsl_azdw_${scriptType}_load' and oo_type_key = 4)
WHERE ta_obj_key = (select oo_obj_key from dbo.ws_obj_object where oo_name = '$azureConnectionName')
AND ta_type = 'L'
;
"@

  $redOdbc = New-Object System.Data.Odbc.OdbcConnection
  $redOdbc.ConnectionString = "DSN=$metaDsn"
  if( ! [string]::IsNullOrEmpty($metaUser)) { $redOdbc.ConnectionString += ";UID=$metaUser" }
  if( ! [string]::IsNullOrEmpty($metaPwd))  { $redOdbc.ConnectionString += ";PWD=$metaPwd" }

  $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
  $command.CommandTimeout = 0
  $command.CommandType = "StoredProcedure"
  $redOdbc.Open()
  [void]$command.ExecuteNonQuery()
  $redOdbc.Close()
}
