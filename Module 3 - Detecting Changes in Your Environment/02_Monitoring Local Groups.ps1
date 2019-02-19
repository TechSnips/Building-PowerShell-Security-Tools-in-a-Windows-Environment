$computerName = 'WSUS'

#region Current local group membership
$scriptBlock = {
	Get-LocalGroupMember -Group 'Administrators' | Select-Object -ExpandProperty Name
}
$previousMembers = Invoke-Command -ComputerName $computerName -ScriptBlock $scriptBlock
$previousMembers
#endregion

#region Commit the current list of members to the file system

## The CSV file that will hold the past states
$monitorStateFilePath = 'C:\LocalGroupMembers.csv'

$now = Get-Date -UFormat '%m-%d-%y %H:%M'
[pscustomobject]@{
	'Time'    = $now
	'Members' = $previousMembers -join ','
} | Export-Csv -Path $monitorStateFilePath -NoTypeInformation -Append

#endregion

#region Add a member
$scriptBlock = {
	Add-LocalGroupMember -Group 'Administrators' -Member 'BadGuy'
}
Invoke-Command -ComputerName $computerName -ScriptBlock $scriptBlock
#endregion

#region New member list
$scriptBlock = {
	Get-LocalGroupMember -Group 'Administrators' | Select-Object -ExpandProperty Name
}
$nowMembers = Invoke-Command -ComputerName $computerName -ScriptBlock $scriptBlock
$nowMembers

#endregion

## Compare and report
if (Compare-Object -ReferenceObject $previousMembers -DifferenceObject $nowMembers) {
	Send-MailMessage
}