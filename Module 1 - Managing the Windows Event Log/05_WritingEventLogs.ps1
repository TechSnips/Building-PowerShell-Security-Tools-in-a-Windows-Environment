#region Write-EventLog
$File = New-Item -Name 'MyFile.txt' -ItemType File

$Params = @{
    "LogName" = 'Application'
    "Source"  = 'Application'
    "EventID" = 1
    "Message" = ("New File: {0}" -F $File.FullName)
}

Write-EventLog @Params

Get-EventLog -LogName 'Application' | Where Source -EQ 'Application' | Select -ExpandProperty Message
#endregion

#region New-EventLog
New-EventLog -Source 'MyApplication' -LogName 'Application'

$Params = @{
    "LogName" = 'Application'
    "Source"  = 'MyApplication'
    "EventID" = 1
    "Message" = ("New File: {0}" -F $File.FullName)
}

Write-EventLog @Params

Get-EventLog -LogName 'Application' | Where Source -EQ 'MyApplication' | Select -ExpandProperty Message
#endregion

#region Get Event Sources
Get-WinEvent -ListProvider *
#endregion