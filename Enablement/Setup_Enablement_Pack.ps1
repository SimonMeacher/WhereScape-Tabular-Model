# --    (c) Wherescape Inc 2020. WhereScape Inc permits you to copy this Script solely for use with the RED software, and to modify this Script         
# --    for the purposes of using that modified Script with the RED software, but does not permit copying or modification for any other purpose.         

param (
  $unmatchedParameter,
  [switch]$help=$false,
  [string]$metaDsn='demo_20220817',
  [string]$metaDsnArch='64',
  [string]$metaUser='demo',
  [string]$metaPwd='demo',
  [string]$metaBase='demo_20220817',
  [string]$tgtDB='demo_20220817',
  [string]$tgtLoadSchema,
  [string]$tgtStageSchema,
  [string]$tgtEdwSchema,
  [string]$tgtDvSchema,
  [string]$tgtDsn,
  [string]$tgtUser='demo',
  [string]$tgtPwd='demo',
  [string]$templateSet,
  [int]$startAtStep=1,
  [switch]$continueOnFailure=$false,
  [string]$redInstallDir='',
  [switch]$upgradeExistingRepo=$false,
  [string]$existingTgtList=''
)

#--==============================================================================
#-- Script Name      :    Setup_Enablement_Pack.ps1
#-- Description      :    Installs the Red Repository and Target Enablement Pack
#-- Author           :    WhereScape, Inc
#--==============================================================================
#-- Notes / History
#-- MME v 1.0.0 2020-07-21 First Version
#-- MME v 1.0.0 2020-08-13 Install the Default Templates to Powershell or Python.

Import-Module -FullyQualifiedName "$PSScriptRoot\Installer Libs\installer_common.psm1" -DisableNameChecking
Import-Module -FullyQualifiedName "$PSScriptRoot\Installer Libs\installer_target.psm1" -DisableNameChecking

# The imported modules require access to the variables set by this script so we test that the script has the global (root scope) context.
$scriptScopeOk = $TRUE 
$res=Test-ScriptScope
if ($res.Outcome -ne 'Success') {
  # print the result
  [PSCustomObject]$res | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
  # stop the script
  Write-Warning "Incorrect Script Run Context. Please run this script in it's own PowerShell session, for example: Powershell -ExecutionPolicy Bypass -File .\Setup_Enablement_Pack.ps1"
  Exit
}

# Minimum Red version for the function in this installer
$minRedVersion = '8.5.1.0'

# Set globals from installer_target.psm1
Set-GlobalVars

$redInstallDir=Get-RedVersion $redInstallDir
$redInstallDir= $($redInstallDir.TrimEnd('\').Trim())

# Build required file and folder paths
$redCliPath=Join-Path -Path $redInstallDir -ChildPath "RedCli.exe"
$defDtmDir=Join-Path -Path $redInstallDir -ChildPath "Administrator\Data Type Mappings"
$defDfsDir=Join-Path -Path $redInstallDir -ChildPath "Administrator\Function Sets"
$wslSched=Join-Path -Path $redInstallDir -ChildPath "WslSched.exe"



# Validate Script Parameters
$targetCmdLineArgs=""
Get-PrimaryScriptParamters $PSBoundParameters $Args

$logLevel=1
$outputMode="json"
$dstDir="C:\temp\"
$schedulerName="WIN0001"
$wslSchedLog="C:\ProgramData\WhereScape\Scheduler\WslSched_${metaDsn}_${schedulerName}.log"
$minRedVerForCompare = [int]$( $minRedVersion -replace "(\d+)\.(\d+)\.(\d+)\.(\d+)",'${1}${2}${3}0${4}' )
$runTimestamp=Get-Date -Format 'MMddhhmmss'
$logFile="$env:TEMP\WsEnbablementPackInstall_$runTimestamp.log"
$redLicense=""
$dbType='Custom'
$metadataRepoExists=$false
$checkLicenseWithTarget=$false
# Print the starting step
if ($startAtStep -ne 1) { Write-Host "Starting from Step = $startAtStep" }

#Build parameters
 Get-EnablementPackProperties $Args

# common RedCli arguments
$commonRedCliArgs = @" 
--meta-dsn "$metaDsn" --meta-dsn-arch "$metaDsnArch" --meta-user-name "$metaUser" --meta-password "$metaPwd" --meta-database "$metaBase" --log-level "$logLevel" --output-mode "$outputMode"
"@


# ---------------------------------------------------------------------------------------------------
# 
#             MAIN INSTALLER PROGRAM BEGINS
#
# ---------------------------------------------------------------------------------------------------

# Create the results hashtable array
[hashtable[]]$results = @()

try { 
  $installStep=1
  #Find and Test the RedCli Version
  Set-RedCliVersion $redCliPath $minRedVersion
  # Set the RED metadata type based on the RedCli version (EP's support either SQL or PostgreSQL) 
  $metaType = Get-MetaType $redCliVersion
	
  # Get Wherescape RED License
	$installStep=2
  $licenseResults= Get-LicenseFromRedCli $redCliPath $metaType
	$res=$licenseResults[0]
	$license=$licenseResults[1]
	[PSCustomObject]$res | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
  $global:results += $res
  if ($res.Outcome -eq 'Failure' -or $res.Outcome -eq 'Error') {
    # stop the script    
		Write-Error "Please install a valid WhereScape RED License for target database type Custom = $tgtLicenseLabel"
    Exit
  }
  
	# Check Wherescape RED License
  $installStep=3
	$res= Test-License $license
	[PSCustomObject]$res | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
  $global:results += $res
  # Check Wherescape RED License is Custom or Named Target
  $redLicense=$res.Information 
  if ($res.Outcome -eq 'Failure' -or $res.Outcome -eq 'Error') {
    # stop the script    
        Write-Error "Please install a valid WhereScape RED License for target database type Custom = $tgtLicenseLabel"
    Exit
  }
 
  if([string]::IsNullOrWhiteSpace($redLicense)){
  $dbType='Common'
  }
  #Check Wherescape RED License and Enablement Pack Match
  if(($dbType -eq "Common" -and  $global:buildDetailsHashtable.'TargetType' -eq "Common") -or 
     ($dbType -ne "Common" -and  $global:buildDetailsHashtable.'TargetType' -eq "Custom"))
  {
      $checkLicenseWithTarget=$true
  }
  if( $checkLicenseWithTarget -eq $false)
  {
     # stop the script    
     Write-Error "WhereScape RED License and Enablement pack are mismatched.Please update license or download valid enablement pack."
    Exit
  }
  
  
  
# Check Wherescape RED Repository Exists
 $installStep=4
 $res= Repository-Exists $commonRedCliArgs 
 
     if ($res.Outcome -eq 'Success')
     {
        $metadataRepoExists=$true
        if($global:upgradeExistingRepo -eq $false)
          {
                      #RED Custom License 
	                    if(![string]::IsNullOrWhiteSpace($redLicense) ) 
                        {
                        #Get the list of Target Connections,this is to set default properties later
                        $existingTgtList = Target-Exists $existingTgtList $redCliPath $commonRedCliArgs
	                  		$tgtDsn = $existingTgtList
                        }
                        #startAtStep is 1 Means its a new install- Ask For upgrade
                        if ($startAtStep -eq 1){
	                  		  $upgradeRepo = Read-Host -Prompt "Upgrade existing repository? (NOTE:Existing Scripts and Templates will be versioned) 'y'/'n'(default) "
                          if ($upgradeRepo -in ('y','Y') )
                          {
                              $filesOverWrite = "--overwrite-existing"
                              $filesOverWriteScripts = "--force"
	                  	        $global:upgradeExistingRepo = $true 
                          }
                          #If no upgrade and startAtStep is 1 then Exit with below error
                          else                        
                          {
                                  Write-Error "Red Metadata repository exists for DSN $metaDsn. Please select upgrade repository or specify -startAtStep > 1"
                                  Exit		   

                          }
                        }
                        #If startAtStep is greater than 1 means previous steps failed -start installation
                        else{
                               $filesOverWrite = "--overwrite-existing"
                               $filesOverWriteScripts = "--force"
                               $global:upgradeExistingRepo = $false                               
                        }
          
          }
          #if upgradeExistingRepo is set to true by user then start installation
          else
          {  
                              $filesOverWrite = "--overwrite-existing"
                              $filesOverWriteScripts = "--force"
	                  	        $global:upgradeExistingRepo = $true         
          }
      
     }
     #Repository Does not exists so start complete installations
     else
     {
      $filesOverWrite = "--overwrite-existing"
      $filesOverWriteScripts = "--force"
	    $global:upgradeExistingRepo = $false

     }
     
  if(![string]::IsNullOrWhiteSpace($redLicense))
  {
    Get-ScriptParamters $PSBoundParameters $Args	  
  }
  
  if([string]::IsNullOrWhiteSpace($redLicense))
  {
    $tgtDsn =$metaDsn
    $tgtUser =$metaUser 
    $tgtPwd =$metaPwd 
    $tgtDB =$metaBase
  }
  
  $scriptType='pscript'
  if(![string]::IsNullOrWhiteSpace($redLicense)){
   if ($templateSet -in 'Python') {
       $scriptType='pyscript'
   }
  }

  if(![string]::IsNullOrWhiteSpace($redLicense)){
   $runtimeConnName='Runtime Connection for Scripts'
   if ($metaType -ne 'SQL') {
   $runtimeConnName='Default Windows Runtime'
   }
  }
  
  # Execute Target Specific Pre-Steps
  $installStep=100
  Execute-PreSteps
	
  # Check Target Connectivity
  if(![string]::IsNullOrWhiteSpace($redLicense)){
  $installStep=200
   if ($installStep -ge $startAtStep -and $upgradeExistingRepo -eq $false) {
   Test-ODBC-Connectivity $tgtDsn $tgtUser $tgtPwd
   } 
  }
  
  # Create RED Metadata Repository
	 if ($upgradeExistingRepo -eq $false -and $metadataRepoExists -eq $false){
   $installStep=300
   Execute-RedCliCommands "repository create" $commonRedCliArgs
   }

  
  # Import Data Type Mappings
  if ($installStep -ge $startAtStep)
  {
   $installStep=400
   $objects = Get-ChildItem "$PSScriptRoot\Data Type Mappings" -Filter '*.xml' | Sort -Property Name
   $defDtmDir = Join-Path -Path $redInstallDir -ChildPath "Administrator\Data Type Mappings"
   foreach($object in $objects) {   
    Execute-RedCliCommands "dtm import --def-dtm-path `"$defDtmDir`" --file-name `"$($object.FullName)`"" $commonRedCliArgs
   }
  }
  
  # Import Database Function Sets
  if ($installStep -ge $startAtStep){
  $installStep=500
  $objects = Get-ChildItem "$PSScriptRoot\Database Function Sets" -Filter '*.xml' | Sort -Property Name
  $defDfsDir = Join-Path -Path $redInstallDir -ChildPath "Administrator\Function Sets"
  foreach($object in $objects) {   
    Execute-RedCliCommands "dfs import --def-dfs-path `"$defDfsDir`" --file-name `"$($object.FullName)`" " $commonRedCliArgs
  }
}
  # Import Extended Properties
    if ( $installStep -ge $startAtStep){
  $installStep=600
  $objects = Get-ChildItem "$PSScriptRoot\Extended Properties" -Filter '*.extprop' | Sort -Property Name
  foreach($object in $objects) {
    Execute-RedCliCommands "ext-prop-definition import --file-name `"$($object.FullName)`" " $commonRedCliArgs   
  }
 }
 
 # Run initial setup commands
  if ($upgradeExistingRepo -eq $false -and $installStep -ge $startAtStep){
   $installStep=700
   Execute-RedCliCommands (Get-GeneralSetupCmds) $commonRedCliArgs
  }
  
  # Add Host Script Languages
  $installStep=800
  if ( $installStep -ge $startAtStep){
  $objects = Get-ChildItem "$PSScriptRoot\Host Script Languages"
  foreach($object in $objects) {
  Execute-RedCliCommands "script-lang-definition import --file-name `"$($object.FullName)`"" $commonRedCliArgs
  }
      }
  
  # Install Templates
  $installStep=900
  if ( $installStep -ge $startAtStep){
   Execute-RedCliCommands (Get-TemplateImportCmds "$PSScriptRoot\Templates"  $dbType $filesOverWrite) $commonRedCliArgs  
  }
  $installStep=1000
  # Install Procedures
  if($installStep -ge $startAtStep){
  Execute-RedCliCommands (Get-ProcedureImportCmds "$PSScriptRoot\Procedures" $filesOverWrite) $commonRedCliArgs  
  }
 
  # Install Scripts
  $installStep=1100
  if($installStep -ge $startAtStep){
    Execute-RedCliCommands ( Get-ScriptImportCmds "$PSScriptRoot\Scripts" $filesOverWriteScripts) $commonRedCliArgs  
  }
  
  # Install UI Configurations
  if (Test-Path -Path "$PSScriptRoot\UI Configurations\"){
   $installStep=1200
   if($installStep -ge $startAtStep){
     Execute-RedCliCommands ( Get-UIConfigImportCmds "$PSScriptRoot\UI Configurations" $filesOverWriteScripts) $commonRedCliArgs  
   }
  }
 
 # Setup Connection Configurations
 $installStep=1300
  if($installStep -ge $startAtStep){
   if ($upgradeExistingRepo -eq $false){
   Execute-RedCliCommands (Get-ConnectionSetupCmds($redLicense)) $commonRedCliArgs
  }
 }
  
 # Setup Default Templates on Target
 $installStep=1400
  if(![string]::IsNullOrWhiteSpace($redLicense) -and $installStep -ge $startAtStep){
   if ($upgradeExistingRepo -eq $false){
    $defaultTemplateCmds = Get-LicensedDefaultTemplateCmds (Get-SetDefaultTemplateCmds) $license.'Licensed Model Type(s)'
     Execute-RedCliCommands $defaultTemplateCmds $commonRedCliArgs  
   }
  }
  
  # Setup RED Options
   $installStep=1500
  if(![string]::IsNullOrWhiteSpace($redLicense) -and $installStep -ge $startAtStep){
    if ($upgradeExistingRepo -eq $false){
    $importOptionsCmd =  @"
     options import -f "$PSScriptRoot\Options\Options.xml"
"@
    Execute-RedCliCommands $importOptionsCmd $commonRedCliArgs
   }
  }
  
  # Deploy RED Applications
  $installStep=1600
  if(![string]::IsNullOrWhiteSpace($redLicense) -and $installStep -ge $startAtStep){
   if ($upgradeExistingRepo -eq $false){
     Execute-RedCliCommands (Get-ApplicationDeploymentCmds "$PSScriptRoot\Deployment Applications") $commonRedCliArgs
    }
  }
  
  # Execute Target Specific Post-Steps
  $installStep=1700
  if(![string]::IsNullOrWhiteSpace($redLicense) -and $installStep -ge $startAtStep){
  Execute-PostSteps
 }
 
 # Setup Object Generation Routine on Target
  $installStep=1800
  if(![string]::IsNullOrWhiteSpace($redLicense) -and $installStep -ge $startAtStep){
   if ($upgradeExistingRepo -eq $false -and $global:templateSet -eq 'Python'){
  Execute-RedCliCommands (Get-ObjectGenerateRoutineTemplateCmds) $commonRedCliArgs
  }
 }
 
 # Add Scheduler
 $installStep=1900
 if($installStep -ge $startAtStep){
  if ($upgradeExistingRepo -eq $false){ 
  Install-RedWindowsScheduler
  }
 }

  Write-Output "`nINFO: Installation Complete, run RED to continue"

} catch {
  Print-Results $results 
  Write-Host $PSItem.Exception.Message
  Write-Host $PSItem.Exception.InnerExceptionMessage
  Exit
}

Print-Results $results