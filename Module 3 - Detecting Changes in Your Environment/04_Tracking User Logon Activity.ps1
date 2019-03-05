function New-AdUserLoginActivityMonitor {
	[OutputType('pscustomobject')]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$UserName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[scriptblock]$Action,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Daily', 'Weekly')]
		[string]$Interval,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Time,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name = ("AD User $UserName Monitor" -replace ' ', '_')
	)

	$ErrorActionPreference = 'Stop'
	
	## Create a big string with template placeholders that will eventually be the PowerShell script
	## that the scheduled task will execute. We're using |<Placeholder>| strings here to insert
	## code when the function runs.
	$monitor = @'
## The CSV file that will hold the past states
$monitorStateFilePath = 'C:\ADUser.csv'

## Get the latest previously stored list of members
$previousLoginTime = $null
$previousLoginTime = Import-Csv -Path $monitorStateFilePath | Sort-Object -Property {[datetime]$_.CaptureTime} -Descending | Select-Object -First 1 | Select-Object -ExpandProperty LastLogin

## Get the user's last login
$dcs = Get-ADDomainController | Select-Object -ExpandProperty HostName

## Have to query all DCs since this LastLogon isn't replicated
$dates = @()
foreach ($dc in $dcs) {
	$dates += Get-ADUser -Filter "samAccountName -eq '|UserName|'" -Properties LastLogonDate | Select-Object -ExpandProperty LastLogonDate
}

## Find the latest one
$lastLoginTime = $dates | Sort-Object -Descending | Select-Object -First 1

## Store the last login time for next time
$now = Get-Date -UFormat '%m-%d-%y %H:%M'
$lastLogin = Get-Date $lastLoginTime -UFormat '%m-%d-%y %H:%M'
[pscustomobject]@{
	'CaptureTime'    = $now
	'LastLoginTime'  = $lastLoginTime
} | Export-Csv -Path $monitorStateFilePath -NoTypeInformation -Append

## Compare and report
if ($previousLoginTime -ne $lastLoginTime) {
	|Action|
}
'@

	## Replace the "Action template" code with
	## the code in $Action and replace the group name with $UserName
	$monitor = $monitor -replace '\|Action\|', $Action.ToString() -replace '\|UserName\|', $UserName
	
	## Create a new scriptblock from the finished code snippet
	$monitor = [scriptblock]::Create($monitor)

	## Pass all of the parameters provided via the function to our custom scheduled task function to
	## quickly create the scheduled task
	$params = @{
		Name         = $Name
		Scriptblock  = $monitor
		Interval     = $Interval
		Time         = $Time
		ComputerName = $ComputerName ## This will be a module-scoped variable in our mini-project
	}
	New-PsScheduledTask @params	
}

## Example usage

## Ensure the text file that will store monitor states is gone
Remove-Item -Path '\\DC\c$\ADUser.csv'

## Define the action to take when a new user logon is detected. This can be anything. We're
## sending an email from my gmail account
$action = {
	$secpasswd = ConvertTo-SecureString 'Ujl04N@LCRq&4OW!lNeU*fGE' -AsPlainText -Force
	$mycreds = New-Object System.Management.Automation.PSCredential ("adbertram@gmail.com", $secpasswd)

	$params = @{
		From       = 'adbertram@gmail.com'
		To         = 'adam@adamtheautomator.com'
		Subject    = 'Detected that techsnips just logged in!'
		Body       = 'Yep, they did.'
		UseSSL     = $true
		SmtpServer = 'smtp.gmail.com'
		Port       = 587
		Credential = $mycreds
	}
	Send-MailMessage @params
}

$params = @{
	UserName     = 'techsnips'
	ComputerName = 'DC'
	Action       = $action
	Interval     = 'Daily'
	Time         = '12:00'
}
New-AdUserLoginActivityMonitor @params

## Start the scheduled task manually to invoke the monitor
Invoke-Command -ComputerName DC -ScriptBlock {Start-ScheduledTask -TaskName 'AD_User_techsnips_Monitor' }

## Login with techsnips somewhere

## Check the monitor states and notifications text files
Import-Csv -Path '\\DC\c$\ADUser.csv'

## Check my email