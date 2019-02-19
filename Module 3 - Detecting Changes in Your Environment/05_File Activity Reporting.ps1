$watcher = New-Object System.IO.FileSystemWatcher
$watcher.IncludeSubdirectories = $true
$watcher.Path = 'C:\FolderWhereStuffChanges'
$watcher.EnableRaisingEvents = $true
#endregion

#region
$action =
{
	$path = $event.SourceEventArgs.FullPath
	$changetype = $event.SourceEventArgs.ChangeType
	Write-Host "$path was $changetype at $(get-date)"
}
#endregion

#region
Register-ObjectEvent $watcher "Created" -Action $action
New-Item -path 'C:\FolderWhereStuffChanges\file.txt' -ItemType File
#endregion

#region
Get-EventSubscriber
Unregister-Event -SubscriptionId 8
#endregion