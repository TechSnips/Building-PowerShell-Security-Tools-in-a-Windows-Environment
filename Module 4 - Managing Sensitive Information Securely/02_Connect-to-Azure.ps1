## Prompts for input. Does not allow seamless execution
$credential = Get-Credential

## Works but you're putting your password in clear text
$userName = 'adbertram@gmail.com'
$password = 'DoNotDoThis' | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)

## Use my credential I saved encrypted on the disk earlier
$credential = Import-CliXml -Path "$($Env:USERPROFILE)\Desktop\Credential.xml"
Connect-AzAccount -Credential $credential