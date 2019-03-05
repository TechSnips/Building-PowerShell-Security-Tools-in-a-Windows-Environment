$path = $event.SourceEventArgs.FullPath
$changetype = $event.SourceEventArgs.ChangeType
Write-Host "$path was $changetype at $(get-date)"