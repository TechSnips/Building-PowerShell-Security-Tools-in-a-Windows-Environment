## Find all of the DCs. Have to query all DCs since this LastLogon isn't replicated
$dcs = Get-ADDomainController | Select-Object -ExpandProperty HostName

## Collect up all of the last logon dates

$userName = 'techsnips'
$dates = @()
foreach ($dc in $dcs) {
	$dates += Get-ADUser -Filter "samAccountName -eq '$userName'" -Properties LastLogonDate | Select-Object -ExpandProperty LastLogonDate
}

## Find the most recent time
$lastLoginTime = $dates | Sort-Object -Descending -First 1

$lastLoginTime

## Define the code the scheduled task will execute
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
$lastLoginTime = $dates | Sort-Object -Descending -First 1

## Store the last login time for next time
$now = Get-Date -UFormat '%m-%d-%y %H:%M'
[pscustomobject]@{
	'CaptureTime'    = $now
	'LastLoginTime'  = $lastLoginTime
} | Export-Csv -Path $monitorStateFilePath -NoTypeInformation -Append

## Compare and report
if ($previousLoginTime -ne $lastLoginTime) {
	|Action|
}
'@

## Define the action to take when a new user logon is detected. This can be anything. We're
## sending an email from my gmail account
$action = {
	$secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
	$mycreds = New-Object System.Management.Automation.PSCredential ("email@domain.local", $secpasswd)

	$params = @{
		From       = 'myemail@gmail.com'
		To         = 'adam@adamtheautomator.com'
		Subject    = 'Detected that techsnips just logged in!'
		Body       = 'Yep, they did.'
		SmtpServer = 'smtp.gmail.com'
		Port       = 587
		Credential = $mycreds
	}
	Send-MailMessage @params
}

## Replace the template variables with real ones
$monitor = $monitor -replace '\|Action\|', $action.ToString() -replace '\|UserName\|', $userName
$monitor = [scriptblock]::Create($monitor)

## The template variables have been replaced
$monitor

## Create the scheduled task
$params = @{
	Name         = 'AD User Login Monitor'
	Scriptblock  = $monitor
	Interval     = 'Daily'
	Time         = '12:00'
	ComputerName = 'DC'
}
New-RecurringScheduledTask @params

## Execute the task
control schedule

## Check out the file
Import-Csv -Path '\\DC\c$\ADUser.csv'