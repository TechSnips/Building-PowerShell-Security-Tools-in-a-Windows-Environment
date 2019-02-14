#region Download One Updates
$updateSession    = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher   = $updateSession.CreateUpdateSearcher()
$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

If ($updates = ($updateSearcher.Search($null))) {
	$updates.updates | Select-Object 'Title', 'IsDownloaded'

	$updates.updates |
		Where-Object Title -Match "Adobe Flash Player" |
		Foreach-Object { $updatesToInstall.Add($_) | Out-Null }

	$downloader         = $updateSession.CreateUpdateDownloader()
	$downloader.Updates = $updatesToInstall
	$downloadResult     = $downloader.Download()

	$updates = $updateSearcher.Search($null)

	$updates.updates | Select-Object 'Title', 'IsDownloaded'
}
#endregion

#region Install One Downloaded Updates
$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

$updates.updates |
	Where-Object IsDownloaded -EQ $true |
	Foreach-Object { $updatesToInstall.Add($_) | Out-Null }

$installer         = New-Object -ComObject 'Microsoft.Update.Installer'
$installer.Updates = $updatesToInstall
$installResult     = $installer.Install()
#endregion

#region Download All Updates
$updateSession = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher = $updateSession.CreateUpdateSearcher()

If ($updates = ($updateSearcher.Search($null))) {
	$updates.updates | Select-Object 'Title', 'IsDownloaded'

	$downloader = $updateSession.CreateUpdateDownloader()
	$downloader.Updates = $updates.updates
	$downloadResult = $downloader.Download()

	$updates = $updateSearcher.Search($null)

	$updates.updates | Select-Object 'Title', 'IsDownloaded'
}
#endregion

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
$DelayMinutes = 2

$scriptBlock = {
	Params(
		$Updates
	)

	$installer         = New-Object -ComObject 'Microsoft.Update.Installer'
	$installer.Updates = $Updates
	$installResult     = $installer.Install()

	If ($installResult.RebootRequired) {
		Exit 7
	} Else {
		$installResult.ResultCode
	}
}

$updateSession    = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher   = $updateSession.CreateUpdateSearcher()
$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

If ($updates = ($updateSearcher.Search($null))) {
	$updates.updates |
		Where-Object Title -Match "Adobe Flash Player" |
		Foreach-Object { $updatesToInstall.Add($_) | Out-Null }

	$downloader         = $updateSession.CreateUpdateDownloader()
	$downloader.Updates = $updatesToInstall
	$downloadResult     = $downloader.Download()

	$Params = @{
		"ScriptBlock"  = $scriptBlock
		"Name"         = "$ComputerName - Windows Update Install"
		"Trigger"      = (New-JobTrigger -At (Get-Date).AddMinutes($DelayMinutes) -Once)
		"ArgumentList" = $updatesToInstall
	}

	Register-ScheduledJob @Params
}
#endregion

#region Remotely Install Updates
$Computers = @(
	'CLIENT'
	'CLIENT2'
)

$scriptBlock = {
	$updateSession    = New-Object -ComObject 'Microsoft.Update.Session'
	$updateSearcher   = $updateSession.CreateUpdateSearcher()
	$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

	If ($updates = ($updateSearcher.Search($Null))) {
		$updates.updates |
			Where-Object Title -Match "Adobe Flash Player" |
			Foreach-Object { $updatesToInstall.Add($_) | Out-Null }

		$downloader         = $updateSession.CreateUpdateDownloader()
		$downloader.Updates = $updatesToInstall
		$downloadResult     = $downloader.Download()

		$installer          = New-Object -ComObject 'Microsoft.Update.Installer'
		$installer.Updates  = $updatesToInstall
		$installResult      = $installer.Install()
	}
}

$Computers | Foreach-Object {
	# Not all computers are ICMP ping enabled, but do support PSRemote which is what we need
	Try {
		Test-WSMan -ComputerName $_ -ErrorAction Stop | Out-Null
	} Catch {
		Return
	}

	$Name = "$($_) - Windows Update Download and Install"

	$Params = @{
		"ComputerName" = $_
		"ScriptBlock"  = $scriptBlock
		"AsJob"        = $true
		"JobName"      = $Name
	}

	Try {
		Invoke-Command @Params
	} Catch {
		Throw $_.Exception.Message
	}
}
#endregion

#region Remotely Schedule Install for Updates
$Computers = @(
	'CLIENT'
	'CLIENT2'
)

$scriptBlock = {
	$scriptBlock = {
		$updateSession = New-Object -ComObject 'Microsoft.Update.Session'
		$updateSearcher = $updateSession.CreateUpdateSearcher()
		$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'

		If ($updates = ($updateSearcher.Search($Null))) {
			$updates.updates |
				Where-Object Title -Match "Adobe Flash Player" |
				Foreach-Object { $updatesToInstall.Add($_) | Out-Null }

			$downloader = $updateSession.CreateUpdateDownloader()
			$downloader.Updates = $updatesToInstall
			$downloadResult = $downloader.Download()

			$installer = New-Object -ComObject 'Microsoft.Update.Installer'
			$installer.Updates = $updatesToInstall
			$installResult = $installer.Install()
		}
	}

	$Params = @{
		"ScriptBlock"  = $scriptBlock
		"Name"         = "$ComputerName - Windows Update Install"
		"Trigger"      = (New-JobTrigger -At (Get-Date).AddMinutes(2) -Once)
		"ArgumentList" = $updatesToInstall
	}

	Register-ScheduledJob @Params
}

$Computers | Foreach-Object {
	# Not all computers are ICMP ping enabled, but do support PSRemote which is what we need
	Try {
		Test-WSMan -ComputerName $_ -ErrorAction Stop | Out-Null
	} Catch {
		Return
	}

	$Name = "$($_) - Windows Update Download and Install Scheduled"

	$Params = @{
		"ComputerName" = $_
		"ScriptBlock"  = $scriptBlock
		"AsJob"        = $true
		"JobName"      = $Name
	}

	Try {
		Invoke-Command @Params
	} Catch {
		Throw $_.Exception.Message
	}
}
#endregion

## This needs an Install-WindowsUpdate function