#region Filter in the event viewer
eventvwr.msc
#endregion

#region Newest
Get-EventLog -LogName Security -Newest 10
#endregion

#region Filtering by time
$after = Get-Date -Date '02/04/2019 00:00:00'

Get-EventLog -LogName Security -After $after

$before = Get-Date -Date '02/03/2019 00:00:00'

Get-EventLog -LogName Security -Before $before

Get-EventLog -LogName Security -Before (Get-Date).AddDays(-1) -After (Get-Date).AddDays(-2)
#endregion

#region Failed audits
$exampleEvent = get-eventlog -EntryType FailureAudit -LogName Security | select -first 1 -Property *


Get-EventLog -LogName System -UserName "*\techsnips"
Get-EventLog -LogName System -UserName "NT*"
#endregion

#region InstanceID
Get-EventLog -LogName System -InstanceID 1500
#endregion

#region Source
Get-EventLog -LogName System -Source 'disk'
#endregion

#region Advanced message parsing
$exampleEvent = get-eventlog -EntryType FailureAudit -LogName Security | select -first 1 -Property *
$exampleEvent
($exampleEvent.Message | Select-String -Pattern 'Account For Which Logon Failed:\r\n\s+Security ID:\s+(.*)' | select -ExpandProperty matches).Groups[1].Value
#endregion