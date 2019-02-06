#region Newest
Get-EventLog -LogName Application -Newest 10
#endregion

#region After
$after = Get-Date -Date '02/04/2019 00:00:00'

Get-EventLog -LogName Application -After $after
#endregion

#region Before
$before = Get-Date -Date '02/03/2019 00:00:00'

Get-EventLog -LogName Application -Before $before
#endregion

#region Username
Get-EventLog -LogName System -UserName "*\techsnips"
Get-EventLog -LogName System -UserName "NT*"
#endregion

#region InstanceID
Get-EventLog -LogName System -InstanceID 1500
#endregion

#region EntryType
Get-EventLog -LogName System -EntryType Error
#endregion

#region Source
Get-EventLog -LogName System -Source 'disk'
#endregion