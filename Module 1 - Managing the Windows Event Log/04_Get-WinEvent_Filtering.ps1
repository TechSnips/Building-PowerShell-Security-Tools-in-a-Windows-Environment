#region Filter By ID
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ID = 1 }
#endregion

#region By UserName - Classic Event Logs
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Data = 'CLIENT\techsnips' }
#endregion

#region By UserName - New Application Logs
Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-PowerShell/Operational'; UserID = 'CLIENT\techsnips' }
#endregion

#region By EntryType
Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Disk' }
#endregion

#region By Time
Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-PowerShell/Operational'; StartTime = '02/05/2019' }
Get-WinEvent -FilterHashtable @{
	LogName   = 'Microsoft-Windows-PowerShell/Operational'
	StartTime = '02/01/2019'
	EndTime   = '02/02/2019'
}
#endregion

#region Query Methods
# HashTable
Get-WinEvent -FilterHashTable @{ LogName = 'System'; ProviderName = 'Disk' }

# FilterXML
$query = @"
<QueryList>
  <Query Id='0' Path='System'>
    <Select Path='System'>*[System[Provider[@Name='disk']]]</Select>
  </Query>
</QueryList>
"@

Get-WinEvent -FilterXML $query

#region Notice XML query in verbose output

#endregion

# FilterXPath
Get-WinEvent -LogName "System" -FilterXPath "*[System[Provider[@Name='disk']]]"
#endregion