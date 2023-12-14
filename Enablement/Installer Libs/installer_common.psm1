# ScriptVersion:005 MinVersion:8310 MaxVersion:* TargetType:Snowflake ModelType:* ScriptType:PowerShell (64-bit)
# --    (c) Wherescape Inc 2020. WhereScape Inc permits you to copy this Module solely for use with the RED software, and to modify this Module            -- #
# --    for the purposes of using that modified Module with the RED software, but does not permit copying or modification for any other purpose.           -- #
#==============================================================================
# Module Name      :    installer_common.psm1
# DBMS Name        :    Generic for all databases
# Description      :    Generic powershell functions module used by many
#                       different installation scripts 
# Author           :    WhereScape Inc
#==============================================================================
# Notes / History
Function Test-ScriptScope {
  $res = @{Step = 0; Outcome = 'Unknown'; Operation = 'Test-ScriptScope'; Information = "Check Script has Global Scope"; Command = ''}
  if ($scriptScopeOk -ne $TRUE) {
    $res.Outcome = 'Failure'
    $res.Information = "Incorrect Script Run Context. Please run this script in it's own PowerShell session, for example: Powershell -ExecutionPolicy Bypass -File .\install_New_RED_Repository.ps1"
   }
  else{
    $res.Outcome = 'Success' 
   }
 return $res
}
# Check for a correct RED Version
Function Get-RedVersion($redInstallDir) {
if ([string]::IsNullOrEmpty($redInstallDir)) {
  $getRedVersion = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName, DisplayVersion, InstallLocation, @{ Name = 'CompareVersion'; Expression = {  [int]$($_.DisplayVersion -replace "\.","") }} | where DisplayName -eq "WhereScape RED" | where CompareVersion -ge $minRedVerForCompare
  write-output($getRedVersion )
  if ($getRedVersion -isnot [array] -and $getRedVersion -ne $null) { 
    $redInstallDir = $getRedVersion.InstallLocation 
  } elseif ($getRedVersion.count -gt 1) {
    Write-Warning "Multiple RED Versions available, please select one from:"
    $getRedVersion | %{ write-host $_.InstallLocation }
    $redInstallDir = Read-Host -Prompt "Please Enter a RED Install Directory from the above list"
  } else {
    Write-Warning "Could not find a compatible RED Version Installed - Please install WhereScape RED 8.5.1.0 or greater to continue."
    Exit
  }
}
return $redInstallDir
}

Function Get-EnablementPackProperties( $cmdArgs = $Args ){
$global:buildDetailsHashtable  = Get-Content "$PSScriptRoot\EnablementPack.properties" | ConvertFrom-StringData
}

Function Get-PrimaryScriptParamters ( $boundParameters = $PSBoundParameters, $cmdArgs = $Args ) {
 # Validate Script Parameters
  if ( $help -or $unmatchedParams ) {
    Print-Help 
    Exit
  } 
  else {
    # Prompt for any required paramaters
    if([string]::IsNullOrEmpty($metaDsn))                 {$global:metaDsn = Read-Host -Prompt "Enter RED MetaRepo DSN"}
    if($boundParameters.count -eq 0 -or ($boundParameters.ContainsKey('startAtStep') -and $boundParameters.count -eq 1)) {
      $global:metaUser = Read-Host -Prompt "Enter RED MetaRepo User or 'enter' for none"
    }
    if(![string]::IsNullOrEmpty($metaUser) -and [string]::IsNullOrEmpty($metaPwd)) {
      $metaPwdSecureString = Read-Host -Prompt "Enter RED MetaRepo Pwd" -AsSecureString
      $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($metaPwdSecureString)
      $global:metaPwd = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    if([string]::IsNullOrEmpty($metaBase))                {$global:metaBase = Read-Host -Prompt "Enter RED MetaRepo DB"}
  }
}

#this function added to check the WS Red license
Function Test-License ( $licenseHashTable ) {
  $res = @{Step = $installStep; Outcome = 'Unknown'; Operation = 'Test-License'; Information = "Check Wherescape RED License"; Command = 'license check'}  
  try {
    if ( $licenseHashTable.'Licensed Target Database Type(s)'.Contains('Custom') -or $licenseHashTable.'Licensed Target Database Type(s)'.Contains('SQL Server')) {     
      $res.Outcome = 'Success'
      $res.Information = $licenseHashTable.'Licensed Custom Target Database Type'
    }
    else {
      $res.Outcome = 'Failure' 
      $res.Information = "License required for target database type Custom = ${tgtLicenseLabel}"  
    }
  } 
  catch {
    $res.Outcome = 'Error' 
    $res.Information = $_.Exception.Message   
  }
  return $res
}

Function Get-LicenseFromRedCli ( $redCliPath, $metaType ) {
  $res = @{Step = $installStep; Outcome = 'Unknown'; Operation = 'Get-License'; Information = "Get Wherescape RED License"; Command = 'license show'}  
  $licenseHashTable = @{}
  $cmdReturn = Execute-Command "RedCli CMD" $redCliPath "license show --output-mode json"
  $cmdReturn.stdout | Out-File -FilePath ${env:TEMP}\WSRedLic_output.txt -Append

  # SQL meta
  if ($metaType -eq 'SQL') {
    try {
      # Extract Batch Json
      $batchJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '^{"Batch":\[').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
      $batchJson = $batchJson | ConvertFrom-Json 
      if (![string]::IsNullOrEmpty($batchJson.Batch[0].Result)) { 
            $res.Outcome = $batchJson.Batch[0].Result
        if ($res.Outcome -eq 'Success') {
          $batchObj = $batchJson.Batch
          $licenseObj = ($batchObj | Where-Object -Property 'Record Set' -EQ 'License').Records
          $licenseObj = $licenseObj | Where-Object -Property 'Record' -EQ 'Lines'          
          foreach( $child in $licenseObj.Fields ) {
            $licenseHashTable[$child.Name] = $child.Value
          }
          $res.Information = $licenseHashTable | ConvertTo-Json
        }
      }
      else {
        $res.Outcome = 'Failure'
        $res.Information = $batchJson.Batch[0]."Error Message"
      }     
    }
    catch {
      $res.Outcome = 'Error'
      $res.Information = $_.Exception.Message
    }
  }
  # PostgreSQL meta
  else {
    # Extract Result Json
    try {
      $cmdResultJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"Result"').Line
      $cmdResultJson = $cmdResultJson.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
      $cmdResultJson = $cmdResultJson | ConvertFrom-Json
      $res.Outcome = $cmdResultJson.MessageBody.Outcome
      $res.Information = $cmdResultJson.MessageBody.Information
    } catch {
      $res.Information = 'No "MessageType":"Result" element found on stdout or could not convert to JSON' 
    }
    # Extract RecordTree Json
    try {
      $recordTree = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"RecordTree"').Line
      $recordTree = $recordTree.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
      $recordTree = $recordTree | ConvertFrom-Json
      $recordTreeObj = $recordTree.MessageBody
      $licenseObj = $recordTreeObj | Where-Object -Property 'Name' -EQ 'License'
      # create hash table from the psobject
      foreach( $child in $licenseObj.Children ) {
        $licenseHashTable[$child.Name] = $child.Value
      }
      $res.Information = $licenseHashTable | ConvertTo-Json
    } catch {
      $res.Information = "$($res.Information). No `"MessageType`":`"RecordTree`" element found on stdout or could not convert to JSON"
    }
    # Extract ProgressEnd Json
    try {
      $progressEnd = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"ProgressEnd"').Line -replace '(^.+\}).*?$','$1'
      $progressEnd = $progressEnd | ConvertFrom-Json
      $res.Operation = $progressEnd.MessageBody.Operation
      if ($progressEnd.MessageBody.ErrorMessage.Trim() -ne '') { 
        $res.Information = "$($res.Information). $($progressEnd.MessageBody.ErrorMessage)"
      }
      $cmdlineError = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"ProgressEnd"').Line -replace '^.+\}(.*?)$','$1' -replace "Content-Type: application/json; charset=utf-8",''
      if ($cmdlineError.Trim().Length -gt 0) {
        $res.Outcome = 'Error'
        $res.Information = "$($res.Information). $cmdlineError"
      }      
    } catch {
      $res.Information = "$($res.Information). No `"MessageType`":`"ProgressEnd`" element found on stdout or could not convert to JSON"
    }  
  } 
  
  if ($cmdReturn.stderr.Trim() -ne '') {
      $res.Outcome = 'Error'
      $res.Information = "$($res.Information). $($cmdReturn.stderr.Trim())"
  }  
  return $res, $licenseHashTable
} 

Function Get-LicensedDefaultTemplateCmds ($defaultTemplateCmds, $license){
  $objFilter = @{
    "Common"="obj-type.+?Load|obj-type.+?Stage|obj-type.+?Export|obj-type.+?Retro|obj-type.+?View";
    "StarSchema"="obj-type.+?Dim|obj-type.+?Agg|obj-type.+?Fact";
    "DataStore"="obj-type.+?Ods";
    "Normal3NF"="obj-type.+?Normal";
    "DataVault"="obj-sub-type.+?DataVaultStage|obj-type.+?Hub|obj-type.+?Link|obj-type.+?Satellite";
    "Custom1"="obj-type.+?Custom1";
    "Custom2"="obj-type.+?Custom2"
  }    
  $cmdArray = @()	
  foreach( $cmd in $defaultTemplateCmds -split '\r\n|\n' ){
    if ( $cmd -match $objFilter.Common -and $cmd -notmatch "obj-sub-type.+?DataVaultStage" ){
      $cmdArray += $cmd
    }
    elseif( $license.Contains('Data Vault') -and $cmd -match $objFilter.DataVault ){
      $cmdArray += $cmd
    } 
    elseif( $license.Contains('Data Store') -and $cmd -match $objFilter.DataStore ){
      $cmdArray += $cmd
    }
    elseif( $license.Contains('3NF') -and $cmd -match $objFilter.Normal3NF ){
      $cmdArray += $cmd
    }
    elseif( $license.Contains('Star Schema') -and $cmd -match $objFilter.StarSchema ){
      $cmdArray += $cmd
    }
    elseif( $license.Contains('Custom1') -and $cmd -match $objFilter.Custom1 ){
      $cmdArray += $cmd
    }
    elseif( $license.Contains('Custom2') -and $cmd -match $objFilter.Custom2 ){
      $cmdArray += $cmd
    }	
  }
  return [string]($cmdArray -join "`n")
}

Function Execute-RedCli-Command-PG ( $commandArguments, $commonArguments="") { 
  # setup result hashtable with defaults 
  $res = @{Step = $installStep; Outcome = 'Failure'; Operation = 'Unknown'; Information = 'A unexpected error occurred'; Command = "$(Remove-Passwords $commandArguments)"} 
  # If environment variable WSL_OUTPUT_ONLY_MODE has been set to true then only ouput the commands don't run them
  if (${env:WSL_OUTPUT_ONLY_MODE} -eq $true) {
    "$commandArguments $commonArguments" | Out-File -FilePath ${env:TEMP}\RedCli_Cmds.txt -Append
    $res = @{Step = $installStep; Outcome = 'Success'; Operation = 'WSL_OUTPUT_ONLY_MODE'; Information = "$commandArguments"; Command = "$(Remove-Passwords $commandArguments)"}
  }
  # Else excute the command  
  else {  
    $cmdReturn = Execute-Command "RedCli CMD" $redCliPath "$commandArguments $commonArguments" 
    $cmdReturn.stdout | Out-File -FilePath ${env:TEMP}\RedCli_output.txt -Append    
    # Extract Result Json
    try {
      $cmdResultJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"Result"').Line
      $cmdResultJson = $cmdResultJson.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
      $cmdResultJson = $cmdResultJson | ConvertFrom-Json
      $res.Outcome = $cmdResultJson.MessageBody.Outcome
      $res.Information = $cmdResultJson.MessageBody.Information
    } catch {
      $res.Information = 'No "MessageType":"Result" element found on stdout or could not convert to JSON' 
    }
    # Extract ProgressEnd Json
    try {
      $progressEnd = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"ProgressEnd"').Line -replace '(^.+\}).*?$','$1'
	  $progressEnd = $progressEnd | ConvertFrom-Json
      $res.Operation = $progressEnd.MessageBody.Operation
      if ($progressEnd.MessageBody.ErrorMessage.Trim() -ne '') { 
        $res.Information = $progressEnd.MessageBody.ErrorMessage
      }
      $cmdlineError = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"ProgressEnd"').Line -replace '^.+\}(.*?)$','$1' -replace "Content-Type: application/json; charset=utf-8",''
      if ($cmdlineError.Trim().Length -gt 0) {
        $res.Outcome = 'Error'
        $res.Information = "$($res.Information). $cmdlineError"
      }      
    } catch {
      $res.Information = "$($res.Information). No `"MessageType`":`"ProgressEnd`" element found on stdout or could not convert to JSON"
    }
if ($commandArguments.StartsWith("repository exists")){
    # Extract RecordTree Json
    try {
      $RecordTree = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"RecordTree"').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8") 
	  $RecordTree = $RecordTree | ConvertFrom-Json
	  $metadataDSN=$RecordTree.MessageBody.Children[0].Value
	  if($RecordTree.MessageBody.Children[1].Value -eq "true"){
		   $res.Outcome = 'Success'
		   $res.Information = "Metadata Repository $metadataDSN Exists"
	  }
	  else{
		  	$res.Outcome = 'Failure'
		    $res.Information = "Metadata Repository $metadataDSN Does Not Exist"
	  } 
    } catch {
      $res.Information = "$($res.Information). No `"MessageType`":`"RecordTree`" element found on stdout or could not convert to JSON"
    }
    if ($cmdReturn.stderr.Trim() -ne '') {
        $res.Outcome = 'Error'
        $res.Information = "$($res.Information). $($cmdReturn.stderr.Trim())"
    }
  }

if ($commandArguments.StartsWith("ext-prop-value show")){
    # Extract RecordTree Json
    try {
      $RecordTree = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"RecordTree"').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8") 
	  $RecordTree = $RecordTree | ConvertFrom-Json
	  $metadataDSN=$RecordTree.MessageBody.Children[0].Value
	  if($RecordTree.MessageBody.Children[5].Name -eq "Data"){
		   $res.Outcome = 'Success'
		   $res.Information = $RecordTree.MessageBody.Children[5].Value 
	  }
	  else{
		  	$res.Outcome = 'Failure'
		    $res.Information = "Extended Property not found"
	  } 
    } catch {
      $res.Information = "$($res.Information). No `"MessageType`":`"RecordTree`" element found on stdout or could not convert to JSON"
    }
    if ($cmdReturn.stderr.Trim() -ne '') {
        $res.Outcome = 'Error'
        $res.Information = "$($res.Information). $($cmdReturn.stderr.Trim())"
    }
  }
  }
  $res
}

Function Execute-RedCli-Command-SQL ( $commandArguments, $commonArguments="" ) {
  # setup result hashtable with defaults 
  $res = @{Step = $installStep; Outcome = 'Failure'; Operation = $($commandArguments -replace '^[ ]*(.+?) -.*$','$1'); Information = ''; Command = "$(Remove-Passwords $commandArguments)"} 
  # If environment variable WSL_OUTPUT_ONLY_MODE has been set to true then only ouput the commands don't run them
  if (${env:WSL_OUTPUT_ONLY_MODE} -eq $true) {
    "$commandArguments $commonArguments" | Out-File -FilePath ${env:TEMP}\RedCli_Cmds.txt -Append
    $res = @{Step = $installStep; Outcome = 'Success'; Operation = 'WSL_OUTPUT_ONLY_MODE'; Information = "$commandArguments"; Command = "$(Remove-Passwords $commandArguments)"}
  }
  # Else excute the command  
  else { 
    $cmdReturn = Execute-Command "RedCli CMD" $redCliPath "$commandArguments $commonArguments"
    $cmdReturn.stdout | Out-File -FilePath ${env:TEMP}\RedCli_output.txt -Append

    # Extract ProgressEnd Json
    try {
      $progressEnd = ($cmdReturn.stdout -split "`n" | Select-String -Pattern ',"Progress End":.+"}').Line -replace '(^.+\}).*?$','$1'
      $progressEnd = $progressEnd | ConvertFrom-Json
      $res.Information = $progressEnd.'Error Message'
      if ($res.Information.Trim() -eq '') {
        $res.Outcome = 'Success'
      }
    } catch {
      $res.Information = ($cmdReturn.stdout -split "`n")[0]
    }    
    # Extract Btach Json
    try {
      $batchJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '^{"Batch":\[').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
      $batchJson = $batchJson | ConvertFrom-Json
      if (![string]::IsNullOrEmpty($batchJson.Batch[0].Result)) { 
        $res.Outcome = $batchJson.Batch[0].Result 
      }
      if (![string]::IsNullOrEmpty($batchJson.Batch[0].Information)) { 
        $res.Information = $batchJson.Batch[0].Information
      }
    } catch {
      if ($res.Outcome -eq 'Failure' -and $res.Information -eq '') {
        $res.Information = "No `"Batch`" element found on stdout or could not convert to JSON" 
      }     
    }  
	if ($commandArguments.StartsWith("repository exists")){
    try {
      $batchJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '^{"Batch":\[').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
      $batchJson = $batchJson | ConvertFrom-Json
	  $metadataDSN=$batchJson.Batch[1].Records[0].Fields[0].Value
	  if($batchJson.Batch[1].Records[0].Fields[1].Value -eq "true"){
		   $res.Outcome = 'Success'
		   $res.Information = "Metadata Repository $metadataDSN Exists"
	  }
	  else{
		  	$res.Outcome = 'Failure'
		    $res.Information = "Metadata Repository $metadataDSN Does Not Exist"
	  } 
      
    } catch {
      if ($res.Outcome -eq 'Failure' -and $res.Information -eq '') {
        $res.Information = "No `"Batch`" element found on stdout or could not convert to JSON" 
      }     
    } 
	}
    if ($cmdReturn.stderr.Trim() -ne '') {
      $res.Outcome = 'Error'
      $res.Information = "$($res.Information). $($cmdReturn.stderr.Trim())"
    }
  }
  $res
}

# Expects a Here String (or String) of RedCli command lines to be executed
Function Execute-RedCliCommands ($cmds, $commonArgs='') {
  $cmdArray = $cmds -split '\r\n|\n'
  for($i=0; $i -lt $cmdArray.Count; $i++) {
    $global:installStep++
    if ($installStep -ge $startAtStep -and ![string]::IsNullOrEmpty($cmdArray[$i])) {
      if ($metaType -eq 'SQL') {
        $res = Execute-RedCli-Command-SQL $cmdArray[$i] $commonArgs
      }
      else {
        $res = Execute-RedCli-Command-PG $cmdArray[$i] $commonArgs
      }
      $global:results += $res
      [PSCustomObject]$res | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
      if ($res.Outcome -ne 'Success' -and $global:continueOnFailure -eq $false) {
        # stop the script
        throw $res.Outcome
      }
    }
  }
}

Function Repository-Exists ( $commonArgs=''){
	 if ($metaType -eq 'SQL') {
        $res = Execute-RedCli-Command-SQL "repository exists" $commonRedCliArgs 
      }
      else {
        $res = Execute-RedCli-Command-PG "repository exists" $commonRedCliArgs 
      }
     $global:results += $res
	 [PSCustomObject]$res | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
	if ($res.Outcome -eq 'Error' -and $global:continueOnFailure -eq $false) {
        # stop the script
        throw $res.Outcome
     }
	 return $res
	
}

# Check for existing target connections
Function Target-Exists($existingTgtList,$redCliPath,$commonRedCliArgs){
if ([string]::IsNullOrEmpty($existingTgtList)) {
	$getTgtConnList = @()
	if ($metaType -eq 'SQL') {
		$cmdReturn = Execute-Command "RedCli CMD" $redCliPath "connection list-all $commonRedCliArgs"
		$cmdReturn.stdout | Out-File -FilePath ${env:TEMP}\WSRedConnList_output.txt -Append
		$batchJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '^{"Batch":\[').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
		$batchJson = $batchJson | ConvertFrom-Json
		if (![string]::IsNullOrEmpty($batchJson.Batch[0].Result)) {
				$resultOutcome = $batchJson.Batch[0].Result
			if ($resultOutcome -eq 'Success') {
			  $batchObj = $batchJson.Batch[1].Records
			  $getConnList = @()
			  foreach( $child in $batchObj.Fields ) {
				$getConnList += $child.Value
			  }
			  foreach($getConn in $getConnList) {
				$connList = '"'+$getConn+'"'
				$tgtCmdReturn = Execute-Command "RedCli CMD" $redCliPath "target list-all --connection-name $connList $commonRedCliArgs"
				$tgtCmdReturn.stdout | Out-File -FilePath ${env:TEMP}\WSRedTgtList_output.txt -Append
				$tgtBatchJson = ($tgtCmdReturn.stdout -split "`n" | Select-String -Pattern '^{"Batch":\[').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
				$tgtBatchJson = $tgtBatchJson | ConvertFrom-Json
				if (![string]::IsNullOrEmpty($tgtBatchJson.Batch[0].Result)) {
					$tgtResultOutcome = $tgtBatchJson.Batch[0].Result
					if ($tgtResultOutcome -eq 'Success') {
						if (![string]::IsNullOrEmpty($tgtBatchJson.Batch[1].Records.Fields)) {
							$getTgtConnList += $getConn
						}
					}
				}
			  }
			}
		}
	} else {
		$cmdReturn = Execute-Command "RedCli CMD" $redCliPath "connection list-all $commonRedCliArgs"
		$cmdResultJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"Result"').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
		$cmdResultJson = $cmdResultJson | ConvertFrom-Json
		$cmdReturn.stdout | Out-File -FilePath ${env:TEMP}\WSRedConnList_output.txt -Append
		$cmdRecordTreeJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"RecordTree"').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
		$cmdRecordTreeJson = $cmdRecordTreeJson | ConvertFrom-Json
		if (![string]::IsNullOrEmpty($cmdResultJson.MessageBody.Outcome)) {
				$resultOutcome = $cmdResultJson.MessageBody.Outcome
			if ($resultOutcome -eq 'Success') {
			  $getConnList = $cmdRecordTreeJson.MessageBody.Children.Children.ForEach({ if ($_.Name -match 'Name') {$_.Value}})
			  foreach($getConn in $getConnList) {
				$connList = '"'+$getConn+'"'
				$tgtCmdReturn = Execute-Command "RedCli CMD" $redCliPath "target list-all --connection-name $connList $commonRedCliArgs"
				$tgtCmdResultJson = ($tgtCmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"Result"').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
				$tgtCmdResultJson = $tgtCmdResultJson | ConvertFrom-Json
				$tgtCmdReturn.stdout | Out-File -FilePath ${env:TEMP}\WSRedTgtList_output.txt -Append
				$tgtCmdRecordTreeJson = ($tgtCmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"RecordTree"').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
				$tgtCmdRecordTreeJson = $tgtCmdRecordTreeJson | ConvertFrom-Json
				if (![string]::IsNullOrEmpty($tgtCmdResultJson.MessageBody.Outcome)) {
					$tgtResultOutcome = $tgtCmdResultJson.MessageBody.Outcome
					if ($tgtResultOutcome -eq 'Success') {
						if (![string]::IsNullOrEmpty($tgtCmdRecordTreeJson.MessageBody.Children[0].Value)) {
							$getTgtConnList += $getConn
						}
					}
				}
			  }
			}
		}
	}
	if ((![string]::IsNullOrEmpty($getTgtConnList)) -and ($getTgtConnList.count -eq 1)) { 
		$existingTgtList = $getTgtConnList
	} elseif ($getTgtConnList.count -gt 1 -and $metaType -eq 'PGSQL') {
	if ( $getTgtConnList[0] -eq 'Range Table Location' ){
  $existingTgtList = $getTgtConnList[1]
  }
  else
  {
	$existingTgtList = $getTgtConnList[0]
  }
  }
  else {
		Write-Warning "Multiple RED Target Connections are available, please select one from:"
		Write-Host $getTgtConnList -Separator "`r`n"
		do {
		$existingTgtList = Read-Host -Prompt "Please Enter a RED Target Connection from the above list"
		} while($getTgtConnList -notcontains $existingTgtList)
	}
}
return $existingTgtList
}

Function Print-Results ([hashtable[]]$results) {
  $header = "####   INSTALLATION SUMMARY   ####"
  $scriptArgsMsg = @"  
`nINFO: Script command line executed (passwords removed): $(Get-ScriptRunCmdLine)
`nINFO: Additional defaulted command line arguments: $targetCmdLineArgs -redInstallDir "$($redInstallDir.TrimEnd('\'))"
"@
  # Write to Host

  Write-Output $header 
  Write-Output $scriptArgsMsg
  $results | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
  Write-Output "Installer log saved to file: $logFile"
  # Write to Log File
  $header | Out-File $logFile -force
  $scriptArgsMsg | Out-File -Append $logFile -force
  $results | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize -Property Step,Outcome,Operation,Information | Out-File $logFile -Append -force
  "####   FAILED COMMANDS   ####" | Out-File $logFile -Append -Force
  $results | ForEach {[PSCustomObject]$_} | Where-Object Outcome -Match "failure|error" | Format-Table -AutoSize -Wrap -Property Step,Outcome,Command | Out-File $logFile -Append -Force
}


Function Check-SchedulerPermissions ($sqlUser='NT AUTHORITY\SYSTEM') {
  Try {
    $sql = @"
      USE $metaBase;  
      BEGIN TRY
        EXECUTE AS USER = '$sqlUser';  
        SELECT permission_name FROM fn_my_permissions(NULL, 'DATABASE')   
          WHERE permission_name IN ('SELECT','INSERT','UPDATE','EXECUTE');
        REVERT;   
      END TRY
      BEGIN CATCH
        SELECT 'none' as permission_name
      END CATCH    
"@
    $conn = New-Object System.Data.Odbc.OdbcConnection
    $conn.ConnectionString = "DSN=$metaDsn"
    if( ! [string]::IsNullOrEmpty($metaUser)) { $conn.ConnectionString += ";UID=$metaUser" }
    if( ! [string]::IsNullOrEmpty($metaPwd))  { $conn.ConnectionString += ";PWD=$metaPwd" }

    $conn.Open()
    $command = New-Object System.Data.Odbc.OdbcDataAdapter($sql,$conn)
    $dataset = New-Object System.Data.DataSet
    $command.Fill($dataset) | out-null
    $permissionsGranted = ''
    foreach ($Row in $dataset.Tables[0].Rows){ 
      $permissionsGranted+= "$($Row[0]), "
    }
    $permissionsGranted = $permissionsGranted -replace ", $"
    $rowCount = $dataset.Tables[0].Rows.Count
    return $rowCount,$permissionsGranted
  } 
  Catch {
    $e = $_.Exception.Message
    return -2,$e
  } 
  Finally {
    $conn.Close()
  }
}

Function Get-TemplateImportCmds ($templateDirectory,$dbType='Custom'){
  $cmds = ""
  $dirRegx = 'Common|Templates'
  if ($metaType -eq 'SQL') {
    $dirRegx += '|SQL' 
  }
  else {
    $dirRegx += '|PostgreSQL'
  }
  $objects = Get-ChildItem "$templateDirectory" -File -Filter "*.peb" -Recurse -Depth 1 | Where-Object -Property Directory -Match $dirRegx
  for($i=0; $i -lt $objects.Count; $i++) {
    # set the base command 
    $cmd = "template import-file --file-name `"$($objects[$i].FullName)`" --overwrite-existing"  
    # get the header line if it exists to extract the TemplateType
    $templateHdrLine = Get-Content $objects[$i].FullName -First 1 
    if ($templateHdrLine -match '^\{#.+TargetType:.+[Objects|ModelType]:.+TemplateType:.+#\}') {
        $tgtType = ($templateHdrLine -replace '.+?TargetType:(.+?)(\b\w+?:.+|-- *#}.*)','$1').Trim()
        $templateType = ($templateHdrLine -replace '.+?TemplateType:(.+?)(\b\w+?:.+|-- *#}.*)','$1').Trim()
    } 
    else { # else no header line found so extract "best guess" TemplateType from file name  
        $templateType = $objects[$i].name -replace "wsl_.*?_","" -replace $objects[$i].Extension,""         
    }
    
    switch -Regex ($templateType) {
      'utility.*' {
          $cmd += " --tem-type Utility --db-type $dbType"
          break;
      }
      '(pscript.*|PowerShell64|PowerShell|PowerShell \(64-bit\) Script)' {
          $cmd += " --tem-type `"PowerShell (64-bit) Script`" --db-type $dbType"
          break;
      }
      '(PowerShell32|PowerShell \(32-bit\) Script)' {
          $cmd += " --tem-type `"PowerShell (32-bit) Script`" --db-type $dbType"
          break;
      }
      '(pyscript.*|Python|Python Script)' {
          $cmd += " --tem-type `"Python Script`" --db-type $dbType"
          break;
      }
      'alter.*' {
          $cmd += " --tem-type Alter --db-type $dbType"
          break;
      }
      'block.*' {
          $cmd += " --tem-type Block --db-type $dbType"
          break;
      }
      'proc.*' {
          $cmd += " --tem-type Procedure --db-type $dbType"
          break;
      }
      '(unix.*|Unix Script|linux)' {
          $cmd += " --tem-type `"Unix Script`" --db-type $dbType"
          break;
      }
      '(create_table|create_view|DDL.*)' {
          $cmd += " --tem-type DDL --db-type $dbType"
          break;
      }
      '(batch|bat|cmd|Windows|Windows Script)' {
          $cmd += " --tem-type `"Windows Script`" --db-type $dbType"
          break;
      }
    }    
    
    $cmds += $cmd
    if ($i -lt $objects.Count - 1){ 
      $cmds +="`n" 
    }
  }  
  return $cmds
}

Function Get-ProcedureImportCmds ($proceduresDirectory) {
  $cmds = ""
  $objects = Get-ChildItem "$proceduresDirectory"
  for($i=0; $i -lt $objects.Count; $i++) {
    $cmd = "procedure import-file --file-name `"$($objects[$i].FullName)`" --force"      
    switch -Regex ($objects[$i].name -replace "wsl_.*?_","" -replace $objects[$i].Extension,"") {
      'Block.*|table_information' {
          $cmd += " --type Block"
          break;
      }
      'Procedure.*' {
          $cmd += " --type Procedure"
          break;
      }
    }    
    $cmds += $cmd
    if ($i -lt $objects.Count - 1){ 
      $cmds +="`n" 
    }
  }
  return $cmds
}

Function Get-ScriptImportCmds ($scriptsDirectory,$filesOverWrite="--force") {
  $cmds = ""
  $objects = Get-ChildItem "$scriptsDirectory"
  for($i=0; $i -lt $objects.Count; $i++) {
    $cmd = "script import-file --file-name `"$($objects[$i].FullName)`" $($filesOverWrite)"      
    switch -Regex ($objects[$i].Extension) {
      '.ps1|.psm1' {
          $cmd += " --type `"PowerShell (64-bit)`""
          break;
      }
      '.bat|.cmd' {
          $cmd += " --type Windows"
          break;
      }
      '.py' {
          $cmd += " --type Python"
          break;
      }
      '.sh' {
          $cmd += " --type Unix"
          break;
      }
    }    
    $cmds += $cmd
    if ($i -lt $objects.Count - 1){ 
      $cmds +="`n" 
    }
  }
  return $cmds
}

Function Get-UIConfigImportCmds ($uiFilesDirectory,$filesOverWrite="--force") {
  $cmds = ""
  $objects = Get-ChildItem "$uiFilesDirectory" -File -Filter '*.uiconfig' | Sort -Property Name
  for($i=0; $i -lt $objects.Count; $i++) {
    $cmd = "ui-config import-file --file-name `"$($objects[$i].FullName)`" $($filesOverWrite)"      
    $cmds += $cmd
    if ($i -lt $objects.Count - 1){ 
      $cmds +="`n" 
    }
  }
  return $cmds
}

#Install Common modules for browse scripts
Function Install-CommonModules($modulesFolderPath) {
	$sourcepath = (Get-ChildItem -file  -Path $modulesFolderPath -Recurse -force | Where-Object Extension -in ('.py','.psm1') | Select-Object -Property name,FullName |Where-Object {$_.Name -like "Wsl*"}).Fullname
	$installDir = "${env:PROGRAMDATA}\WhereScape\Modules"
	foreach($fileName in $sourcepath){
		$installStep = $installStep+1
		$res = @{Step = $installStep; Outcome = 'Unknown'; Operation = 'Install-CommonModules'; Information = "{Install Common Modules}"; Command = ''}
		if($fileName.EndsWith('.py')){
			$modName = "WslPython"
			  if( ! (Test-Path $(Join-Path -Path $installDir -ChildPath $modName))) {
				New-Item $(Join-Path -Path $installDir -ChildPath $modName) -ItemType Container
			  } 
			  $destinationPathPython = Join-Path -path $installDir -ChildPath $modName
			  Copy-Item $fileName -Destination $destinationPathPython 
			  $res.Outcome = 'Success'
			  $res.Information = "{The file $fileName copied to $destinationPathPython}"		 		
		}
		elseif($fileName.EndsWith('psm1'))
		{
			  $modName = "WslPowershellTemplate"
			  if( ! (Test-Path $(Join-Path -Path $installDir -ChildPath $modName))) {
				New-Item $(Join-Path -Path $installDir -ChildPath $modName) -ItemType Container
			  }  
			  $destinationPathPowershell = Join-Path -path $installDir -ChildPath $modName
			  Copy-Item $fileName -Destination $destinationPathPowershell
			  $res.Outcome = 'Success'
			  $res.Information = "{The file $fileName copied to $destinationPathPowershell}"
		}
		$global:results += $res
		[PSCustomObject]$res | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
		if ($res.Outcome -ne 'Success' -and $continueOnFailure -eq $false) {
			# stop the script
			throw $res.Outcome
		}
	}	
}

Function Test-ODBC-Connectivity ($dsn, $user='', $pw=''){
  $res = @{Step = $installStep; Outcome = 'Unknown'; Operation = 'Test-ODBC-Connectivity'; Information = "Testing ODBC connection to: $dsn, use '-startAtStep $($installStep+1)' to skip this test"; Command = "Testing ODBC connection to DSN: $dsn"}
  $conn = New-Object Data.Odbc.OdbcConnection
  $conString = "DSN=$dsn"
  if (![string]::IsNullOrEmpty($user)) {
    $conString += ";UID=$user"
    if (![string]::IsNullOrEmpty($pw)) {
      $conString += ";PWD=$pw"
    }
  }
  $conn.ConnectionString = $conString
  try { 
	$conn.open() 			
    if ($conn.State -eq 'Open') { 
      $conn.Close() 
      $res.Outcome = 'Success' 
    } 
    else {
      $conn.Close()
      $res.Outcome = 'Failure'
    }
  } catch {    
    $res.Outcome = 'Failure' 
    $res.Information = $_.Exception.Message
  }
  $global:results += $res
  [PSCustomObject]$res | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
  if ($res.Outcome -ne 'Success' -and $global:continueOnFailure -eq $false) {
    # stop the script
    throw $res.Outcome
  }
}

Function Install-RedWindowsScheduler {
  # Create a RED Scheduler
  if ($installStep -ge $startAtStep -and $metaType -eq 'SQL') {
    $res = @{Step = $installStep; Outcome = 'Unknown'; Operation = 'Scheduler Permissions'; Information = "Checked RED Metadata permissions for 'NT AUTHORITY\SYSTEM'"; Command = "$(Remove-Passwords $addSchedCmd)"}
    Write-Output "`nFinal step: Installing the RED Scheduler, if this step fails you can manually install the RED Scheduler through RED Setup Administrator (ADM.exe)`n"
    $installScheduler =$true
    $addSchedCmd =  @"
scheduler add --service-name "$metaDsn" --scheduler-name "$schedulerName" --exe-path-name "$wslSched" --sched-log-level 2 --log-file-name "$wslSchedLog" --sched-meta-dsn-arch "$metaDsnArch" --sched-meta-dsn "$metaDsn" --sched-meta-user-name "$metaUser" --sched-meta-password "$metaPwd" --login-mode "LocalSystemAccount" --ip-service tcp --host-name "${env:COMPUTERNAME}" --output-mode json
"@
    # For Windows Authentication check the metadata db for 'NT AUTHORITY\SYSTEM' permissions
    if([string]::IsNullOrEmpty($metaUser)) {
      $hasPermissions = Check-SchedulerPermissions 'NT AUTHORITY\SYSTEM'
      if ($hasPermissions[0] -ne 4) {
        $installScheduler =$false
        #Write-Warning "Failed at step = $installStep, please manually install the RED Scheduler through RED Setup Administrator (ADM.exe), or grant the required permission and restart this step"  
        #Write-Output "INFO: NT AUTHORITY\SYSTEM does not have the required persmissions on the RED Metadata database. The RED Scheduler user must have at least SELECT,INSERT,UPDATE and EXECUTE"
        $res.Outcome = 'Failure'           
        if ($hasPermissions[0] -eq -2) {
          Write-Warning $hasPermissions[1].toString()
          $res.Information = "NT AUTHORITY\SYSTEM permission error. $($hasPermissions[1].toString())"
        } else {
          $res.Information = "NT AUTHORITY\SYSTEM permission error. Permissions found: $($hasPermissions[1].toString()). Permissions required: SELECT,INSERT,UPDATE and EXECUTE"
        }
      } else {
		$res.Outcome = 'Success'
	}	
      $global:results += $res
	  [PSCustomObject]$res | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
	  if ($res.Outcome -ne 'Success' -and $global:continueOnFailure -eq $false) {
		# stop the script
		throw $res.Outcome
	  }
    }
    if($installScheduler) {
      Execute-RedCliCommands $addSchedCmd
    }
  }
}

Function Get-ScriptRunCmdLine {
  # Return the common mandatory command line args provided to the script (passwords removed)
if ($metaType -eq 'PGSQL') {
  $cmdLineArgs = @"
Powershell -ExecutionPolicy Bypass -File .\StartScriptTrigger.ps1 -metaDsn "$metaDsn" -metaDsnArch "$metaDsnArch" $( if(![string]::IsNullOrEmpty($metaUser)){"-metaUser ""$metaUser"" "}) -metaBase "$metaBase" $( if(![string]::IsNullOrEmpty($tgtDB)){"-tgtDB ""$tgtDB"" "})$( if(![string]::IsNullOrEmpty($tgtLoadSchema)){" -tgtLoadSchema ""$tgtLoadSchema"" "})$( if(![string]::IsNullOrEmpty($tgtStageSchema)){" -tgtStageSchema ""$tgtStageSchema"" "})$( if(![string]::IsNullOrEmpty($tgtEdwSchema)){" -tgtEdwSchema ""$tgtEdwSchema"" "})$( if(![string]::IsNullOrEmpty($tgtDvSchema)){" -tgtDvSchema ""$tgtDvSchema"" "})$( if(![string]::IsNullOrEmpty($tgtDsn)){" -tgtDsn ""$tgtDsn"" "})$( if(![string]::IsNullOrEmpty($tgtUser)){" -tgtUser ""$tgtUser"" "}) -startAtStep $startAtStep
"@
}

else {
  $cmdLineArgs = @"
Powershell -ExecutionPolicy Bypass -File .\Setup_Enablement_Pack.ps1 -metaDsn "$metaDsn" -metaDsnArch "$metaDsnArch" $( if(![string]::IsNullOrEmpty($metaUser)){"-metaUser ""$metaUser"" "}) -metaBase "$metaBase" $( if(![string]::IsNullOrEmpty($tgtDB)){"-tgtDB ""$tgtDB"" "})$( if(![string]::IsNullOrEmpty($tgtLoadSchema)){" -tgtLoadSchema ""$tgtLoadSchema"" "})$( if(![string]::IsNullOrEmpty($tgtStageSchema)){" -tgtStageSchema ""$tgtStageSchema"" "})$( if(![string]::IsNullOrEmpty($tgtEdwSchema)){" -tgtEdwSchema ""$tgtEdwSchema"" "})$( if(![string]::IsNullOrEmpty($tgtDvSchema)){" -tgtDvSchema ""$tgtDvSchema"" "})$( if(![string]::IsNullOrEmpty($tgtDsn)){" -tgtDsn ""$tgtDsn"" "})$( if(![string]::IsNullOrEmpty($tgtUser)){" -tgtUser ""$tgtUser"" "}) -startAtStep $startAtStep
"@
}
  return $cmdLineArgs
}

Function Remove-Passwords ($stringWithPwds) { 
  $stringWithPwdsRemoved = $stringWithPwds
  if (![string]::IsNullOrEmpty($metaPwd)){ 
    $stringWithPwdsRemoved = $stringWithPwdsRemoved -replace "(`"|`'| ){1}$([Regex]::Escape($metaPwd))(`"|`'| |$){1}",'$1***$2'
  } 
  if (![string]::IsNullOrEmpty($postgresPwd)){ 
    $stringWithPwdsRemoved = $stringWithPwdsRemoved -replace "(`"|`'| ){1}$([Regex]::Escape($postgresPwd))(`"|`'| |$){1}",'$1***$2'
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
Function Set-RedInstallDir ($minRedVersion='8.5.1.0') {
  # Check for a correct RED Version
  if ([string]::IsNullOrEmpty($global:redInstallDir)) {
    $minRedVerForCompare = [int]$( $minRedVersion -replace "(\d+)\.(\d+)\.(\d+)\.(\d+)",'${1}${2}${3}0${4}' )
    $getRedVersion = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName, DisplayVersion, InstallLocation, @{ Name = 'CompareVersion'; Expression = {  [int]$($_.DisplayVersion -replace "\.","") }} | where DisplayName -eq "WhereScape RED" | where CompareVersion -ge $minRedVerForCompare
    if ($getRedVersion -isnot [array] -and $getRedVersion -ne $null) { 
      $global:redInstallDir = $getRedVersion.InstallLocation 
    } elseif ($getRedVersion.count -gt 1) {
      Write-Warning "Multiple RED Versions available, please select one from:"
      $getRedVersion | %{ write-host $_.InstallLocation }
      $global:redInstallDir = Read-Host -Prompt "Please Enter a RED Install Directory from the above list"
    } else {
      Write-Warning "Could not find a compatible RED Version Installed - Please install WhereScape RED 8.5.1.0 or greater to continue."
      Exit
    }
  }
}

Function Set-RedCliVersion ($redCliPath, $minRedVersion='8.5.1.0') {
    $global:redCliVersion = '0.0.0.0'																		 
    # setup result hashtable with defaults 
    $res = @{Step = $installStep; Outcome = 'Failure'; Operation = 'RED Version'; Information = 'A unexpected error occurred'; Command = "--version --output-mode json"} 
    if (Test-Path $redCliPath) {
      $cmdReturn = Execute-Command "RedCli CMD" $redCliPath "--version --output-mode json" 
      $cmdReturn.stdout | Out-File -FilePath ${env:TEMP}\RedCli_output.txt -Append    
      If ($cmdReturn.stdout -match '"MessageType":"Result"') {
          # RED PostgreSQL
          $cmdResultJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"Result"').Line
          $cmdResultJson = $cmdResultJson.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
          $cmdResultJson = $cmdResultJson | ConvertFrom-Json
          $res.Outcome = $cmdResultJson.MessageBody.Outcome
          $cmdRecordTreeJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '"MessageType":"RecordTree"').Line
          $cmdRecordTreeJson = $cmdRecordTreeJson.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
          $cmdRecordTreeJson = $cmdRecordTreeJson | ConvertFrom-Json
          $ver=$cmdRecordTreeJson.MessageBody.Children[0].Children.ForEach({ if ($_.Name -match 'File Version') {$_.Value}}) 
          $build=$cmdRecordTreeJson.MessageBody.Children[0].Children.ForEach({ if ($_.Name -match 'Build Number') {$_.Value}})
          $res.Information = "$ver $build"     
      }
      elseif($cmdReturn.stdout -match '"Progress Begin":"VersionCommand"') {
          # RED SQL Server
          $batchJson = ($cmdReturn.stdout -split "`n" | Select-String -Pattern '^{"Batch":\[').Line.Trim().TrimEnd("Content-Type: application/json; charset=utf-8")
          $batchJson = $batchJson | ConvertFrom-Json
          if (![string]::IsNullOrEmpty($batchJson.Batch[0].Result)) { 
          $res.Outcome = $batchJson.Batch[0].Result 
          }
          $ver=$batchJson.Batch[1].Records[0].Fields.ForEach({ if ($_.Name -match 'File Version') {$_.Value}})
          $build=$batchJson.Batch[1].Records[0].Fields.ForEach({ if ($_.Name -match 'Build Number') {$_.Value}})
          $res.Information = "$ver $build"
      } 
      else {
        $res.Outcome = 'Error'
        $res.Information = "$($res.Information). $($cmdReturn.stderr.Trim())"
      } 
    }
    else {
      $res.Outcome = 'Error'
      $res.Information = "RedCli.exe can not be found at: $redCliPath"      
    }

    if ($res.Outcome -eq 'Success') {
      $global:redCliVersion = ($res.Information -split ' ')[0]
      $thisRedVersion = [int]$( ($res.Information -split ' ')[0] -replace "(\d+)\.(\d+)\.(\d+)\.(\d+)",'${1}${2}${3}0${4}' ) 
      $minRedVerForCompare = [int]$( $minRedVersion -replace "(\d+)\.(\d+)\.(\d+)\.(\d+)",'${1}${2}${3}0${4}' )
      if ($thisRedVersion -lt $minRedVerForCompare) {
        $res.Outcome = 'Failure'
        $res.Information = "Minium RED version: $minRedVersion, this RED version: $redCliVersion, the script can not continue"
      }      
    }    
  $global:results += $res
  [PSCustomObject]$res | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
  if ($res.Outcome -ne 'Success') {
    # stop the script
    throw $res.Outcome
  }
}

Function Get-MetaType ($redCliVersionDotNotation) {
  # determine the RED Meta Type based on RedCli Version
  $redCliVersion = [int]$( $redCliVersionDotNotation -replace "(\d+)\.(\d+)\.(\d+)\.(\d+)",'${1}${2}${3}0${4}' )
  if ($redCliVersion -ge 200100) {
    $metaType = 'PostgreSQL'
  }
  else {
    $metaType = 'SQL'
  }
  return $metaType
}

#this function added to run sql queries from the target functions
Function Execute-SQL-Block ($sql) {
  $res = @{Step = $installStep; Outcome = 'Unknown'; Operation = 'Execute-SQL-Block'; Information = "{Execute SQL Queries from ODBC connection to: $metaDsn}"; Command = ''}
  $conn = New-Object Data.Odbc.OdbcConnection
  $conn.ConnectionString= "DSN=$metaDsn"
  if( ! [string]::IsNullOrEmpty($metaUser)) { $conn.ConnectionString += ";UID=$metaUser" }
  if( ! [string]::IsNullOrEmpty($metaPwd))  { $conn.ConnectionString += ";PWD=$metaPwd" }
  $command = New-Object System.Data.Odbc.OdbcCommand($sql,$conn)
  $command.CommandTimeout = 0
  $command.CommandType = "StoredProcedure"
  try { 
    $conn.open() 
    if ($conn.State -eq 'Open') { 
      [void]$command.ExecuteNonQuery()
	  $conn.Close()
      $res.Outcome = 'Success' 
    } 
    else {
	  $conn.Close()
      $res.Outcome = 'Failure'
    }
  } catch {    
    $res.Outcome = 'Failure' 
    $res.Information = $_.Exception.Message
  }
  $global:results += $res
  [PSCustomObject]$res | Format-Table -AutoSize -Wrap -Property Step,Outcome,Operation,Information
  if ($res.Outcome -ne 'Success' -and $global:continueOnFailure -eq $false) {
    # stop the script
    throw $res.Outcome
  }
}