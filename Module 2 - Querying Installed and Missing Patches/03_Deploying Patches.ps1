#region Download & Install Updates
$updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher = $updateSession.CreateUpdateSearcher()

If ($updates = ($updateSearcher.Search($null))) {
	$downloader         = $updateSession.CreateUpdateDownloader()
	$downloader.Updates = $updates.updates
	$downloadResult     = $downloader.Download()

	If ($downloadResult.ResultCode -ne 2) {
		Exit $downloadResult.ResultCode;
	}

	$installer         = New-Object -ComObject 'Microsoft.Update.Installer'
	$installer.Updates = $updates
	$installResult     = $installer.Install()

	If ($installResult.RebootRequired) {
		Exit 7
	} Else {
		$installResult.ResultCode
	}
}
#endregion

#region Defer Execution of Install
$ComputerName = 'localhost'

$scriptBlock = {
	Params(
		$Updates
	)

	$installer         = New-Object -ComObject 'Microsoft.Update.Installer'
	$installer.Updates = $updates
	$installResult     = $installer.Install()

	If ($installResult.RebootRequired) {
		Exit 7
	} Else {
		$installResult.ResultCode
	}
}

$updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher = $updateSession.CreateUpdateSearcher()

If ($updates = ($updateSearcher.Search($null))) {
	$downloader         = $updateSession.CreateUpdateDownloader()
	$downloader.Updates = $updates.updates
	$downloadResult     = $downloader.Download()

	$Params = @{
		"ScriptBlock"  = $scriptBlock
		"Name"         = "$ComputerName - Windows Update Install"
		"Trigger"      = (New-JobTrigger -At (Get-Date).AddHours(2) -Once)
		"ArgumentList" = $Updates.updates
	}

	Register-ScheduledJob @Params
}
#endregion
