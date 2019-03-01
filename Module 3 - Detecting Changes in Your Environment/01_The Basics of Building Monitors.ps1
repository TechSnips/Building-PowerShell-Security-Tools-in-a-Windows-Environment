<#
	Scenario:
		- Find a file's hash value
		- Store the hash value and contents
		- Change the file
		- Compare hash values
		- Report on changed content

	Trigger --> Compare --> Action
#>

## Create a demo text file
$filePath = 'C:\SuperSecretSensitiveInfo.txt'
Set-Content -Path $filePath -Value 'FROM: Manager - Adam needs to receive more money!'

Get-Content -Path $filePath

#region The monitoring event

## Store the current content (capturing state)
$nowContent = Get-Content -Path $filePath

## Capture the current hash (capturing state)
$nowHash = Get-FileHash -Path $filePath

## Change the file somehow
Set-Content -Path $filePath -Value 'FROM: Manager - Adam needs to be canned.'

## Store the current content (capturing state)
$thenContent = Get-Content -Path $filePath

## Capture the current hash (capturing state)
$thenHash = Get-FileHash -Path $filePath

#region Comparing and reporting states
$nowHash.Hash -eq $thenHash.Hash

$nowContent
$thenContent

$nowContent -eq $thenContent

## Adding the condition
if ($nowHash.Hash -ne $thenHash.Hash) {
	## Add any action of your choice here
	Write-Host "Oh noes! The file content went from [$($nowContent)] to [$($thenContent)]!"
} else{
	Write-Host "The file did not change."
}
#endregion

#region Scheduling the monitor

## Wrap code in a scriptblock and add a method to save state
$monitor = {
	$monitorStateFilePath = 'C:\MonitorState.txt'
	$filePathToMontor = 'C:\SuperSecretSensitiveInfo.txt'

	## Get the previously stored hash (if it exists at all)
	$previousHash = $null
	$previousHash = Get-Content -Path $monitorStateFilePath -ErrorAction Ignore

	## Get the current hash
	$currentHash = (Get-FileHash -Path $filePathToMontor).Hash

	## Commit the hash to the file system to check next time
	Set-Content -Path $monitorStateFilePath -Value $currentHash
	
	## Compare and report
	if ($previousHash -ne $currentHash) {
		$now = Get-Date -UFormat '%m-%d-%y %H:%M'
		$reportFilePath = 'C:\MonitorReport.txt'
		Add-Content -Path $reportFilePath -Value "$now | Oh noes! The file content changed!"
	}
}

$params = @{
	ComputerName = 'DC'
	Name         = 'BasicFileMonitor'
	Scriptblock  = $monitor
	Interval     = 'Daily'
	Time         = '12:00'
}
New-PsScheduledTask @params

## Secret file on remote server
Get-Content -Path '\\DC\c$\SuperSecretSensitiveInfo.txt'

## No monitor state file
Test-Path -Path '\\DC\c$\MonitorState.txt'

## Manually run the task to capture the first state
Invoke-Command -ComputerName DC -ScriptBlock { Start-ScheduledTask -TaskName 'BasicFileMonitor' }

## Monitor file exists now with the current hash
Get-Content -Path '\\DC\c$\MonitorState.txt'

## Change the file
Set-Content -Path '\\DC\c$\SuperSecretSensitiveInfo.txt' -Value 'I see this --bad guy'

## Manually run the scheduled task again to capture state, compare and take action
Invoke-Command -ComputerName DC -ScriptBlock { Start-ScheduledTask -TaskName 'BasicFileMonitor' }

## Check the monitor report file
Get-Content -Path '\\DC\c$\MonitorReport.txt'

#endregion