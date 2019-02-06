$Computers = @(
    'DC'
)

$Logs = @(
    "Application"
    "System"
)

# Specify Start and End Dates to Retrieve Event Logs
$StartTimestamp = Get-Date "02-01-2019 00:00:00" -Format "MM-dd-yyyy"
$EndTimeStamp   = Get-Date -Format "MM-dd-yyyy"

# The Output Text File
$OutputFilePath = "$($Env:USERPROFILE)\Desktop\EventLogs.txt"

$Computers | ForEach-Object {
    $Computer = $_

    If (-Not $Logs) {
        Write-Host "Retrieving All Log Entries on $Computer"
        $AllLogs = Get-WinEvent -ListLog * -ComputerName $Computer

        $AllLogs | Foreach-Object {
            $LogName = $_
            $Results = @()

            If ($StartTimestamp -And $EndTimeStamp) {
                $Results += Get-WinEvent -ComputerName $Computer -FilterHashtable @{
                    'LogName'   = $LogName
                    'StartTime' = $StartTimestamp
	                'EndTime'   = $EndTimeStamp
                }
            } Else {
                $Results = Get-WinEvent -LogName $LogName  -ComputerName $Computer
            }
        }
    } Else {
        $Results = @()

        $Logs | Foreach-Object {
            Write-Host "Retrieving Log Entries for $($_) on $Computer"
            $LogName = $_

            If ($StartTimestamp -And $EndTimeStamp) {
                $Results += Get-WinEvent -ComputerName $Computer -FilterHashtable @{
                    'LogName'   = $LogName
                    'StartTime' = $StartTimestamp
	                'EndTime'   = $EndTimeStamp
                }
            } Else {
                $Results += Get-WinEvent -LogName $LogName -ComputerName $Computer
            }
        }
    }

    Write-Host "Writing Log Entries to Text File"
    $Results |
       Select-Object TimeCreated, ProviderName, Id, Message, LogName |
       Format-Table -Wrap -Property TimeCreated, ProviderName, Id, Message, LogName -Autosize |
       Out-File -FilePath $OutputFilePath -Force -Append
}
