# --    (c) Wherescape Inc 2020. WhereScape Inc permits you to copy this Script solely for use with the RED software, and to modify this Script         
# --    for the purposes of using that modified Script with the RED software, but does not permit copying or modification for any other purpose.         
#--==============================================================================
#-- Script Name      :    WslPowershellInstall.ps1
#-- Description      :    Installs the Powershell Common Modules
#-- Author           :    WhereScape, Inc
#--==============================================================================
#-- Notes / History


$scriptDir = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
$installDir = "${env:PROGRAMDATA}\WhereScape\Modules"

$fileList = Get-ChildItem $scriptDir | Where { $_.name -like "WslPowershell*.psm1" }

foreach($file in $fileList) {
    $fileName = $file.Name
    $modName = $fileName.Replace(".psm1","")
    $destinationDirectory = Join-Path -Path $installDir -ChildPath $modName
    $destinationFileFullName = Join-Path -Path $destinationDirectory -ChildPath $fileName
    if( ! (Test-Path $destinationDirectory)) {
        New-Item $destinationDirectory -ItemType Container -Force
    }
    Copy-Item $file.FullName -Destination $destinationFileFullName -Force
    try {
        if ( Get-Item -Path $destinationFileFullName -Stream 'Zone.Identifier' -ErrorAction Ignore ) {
        Unblock-File $destinationFileFullName
		}																																					  
    } catch {
      Write-Warning "Attempt to `"Unblock`" module file $fileName failed, it may be locked by your virus scanner or you do not have the required permissions."
      Write-Warning "Please manually unblock this file after the install at: $destinationFileFullName"
      Write-Output "Exception message: $($_.Exception.Message)"
      $Error.Clear()
	}
}

if($Error.Count -eq 0) {
    Write-Output "Modules installed successfully"
}
else {
    Write-Output "An error occurred while installing modules"
    $Error | Write-Output
    $Error.Clear()
}

try {
    foreach($path in ${env:PsModulePath}.Split(';')) {
        if($path -eq $installDir) {
            $exists = $true
        }
    }

    if( ! $exists) {
        $env:PsModulePath += ";$installDir"
        [Environment]::SetEnvironmentVariable( "PsModulePath", ${env:PsModulePath}, [System.EnvironmentVariableTarget]::Machine )
        Write-Output "Successfully updated PSMODULEPATH environment variable"
    }
    else {
        Write-Output "PSMODULEPATH does not need to be updated"
    }
}
catch {
    Write-Output "Failed to update PSMODULEPATH"
}