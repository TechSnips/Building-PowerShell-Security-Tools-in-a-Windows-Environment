#region List Logs
Get-WinEvent -ListLog *
Get-WinEvent -ListLog Setup | Format-List -Property *
#endregion

#region List Providers
Get-WinEvent -ListProvider * | Select-Object -Property Name
(Get-WinEvent -ListLog Application).ProviderNames
(Get-WinEvent -ListProvider Microsoft-Windows-GroupPolicy).Events | Format-Table ID, Description -AutoSize
#endregion

#region Returned Object Properties
Get-WinEvent -LogName Application | Select-Object -Property * -First 1
#endregion

#region Get Events
Get-WinEvent -LogName Application -MaxEvents 50

Get-WinEvent -LogName Application -MaxEvents 50 |
    Select-Object TimeCreated, ProviderName, Id, Message |
    Format-Table -AutoSize
#endregion