## Scenario: Query updates different ways on a local and remote computer

#region Explain the entire process without the function all in one go in it's simplest form
$updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
$updateSearcher = $updateSession.CreateUpdateSearcher()
$query = 'IsInstalled=0'
$updates = ($updateSearcher.Search($query))

## Show there's not much good output here
$updates

## Need to drill down into the updates property
$updates.Updates

## Limit to only interesting data
$updates.Updates | Select-Object Title, LastDeploymentChangeTime, Description, RebootRequired, IsDownloaded, IsHidden
#endregion

#region Hit another use case or two trying not to repeat much from above

## Find Updates Required a Reboot
$Updates = $UpdateSearcher.Search('RebootRequired=1')
$Updates.Updates | Select-Object Title, Description, RebootRequired, IsDownloaded, IsHidden

## Multiple Conditions
$Updates = $UpdateSearcher.Search('IsInstalled=0 AND RebootRequired=1')
$Updates.Updates | Select-Object Title, Description, RebootRequired, IsDownloaded, IsHidden

#endregion

#region Using Get-HotFix
# Retrieves hotfixes (updates) that have been installed by Windows Update, Microsoft Update, Windows Server Updates
# Pulls data from the WMI class: Win32_QuickFixEngineering
# This class only reutnrs updates supplied by Compoonent Based Servicing (CBS). Updates supplied by MSI or the Windows Update Site are not returned.
Get-HotFix
Get-HotFix -ComputerName 'DC'
#endregion

#region Search by Category
$UpdateObjectSearcher = New-Object -ComObject 'Microsoft.Update.Searcher'
$InstalledUpdates     = $UpdateObjectSearcher.Search("IsInstalled=1")
$InstalledUpdates.Updates | % {$_.Categories | % {$_.Name}}

$InstalledUpdates.Updates | Where-Object { 'Security Updates' -in ($_.Categories | foreach { $_.Name }) } | Select-Object Title, LastDeploymentChangeTime
#endregion

## Other query options
## RebootRequired=1, IsHidden=1, IsAssigned=1, IsInstalled=0 AND RebootRequired=1

#region Get Updates on a Remote Computer (PSRemoting)
$scriptblock = {
	$UpdateObjectSession = New-Object -ComObject 'Microsoft.Update.Session'
	$UpdateSearcher      = $UpdateObjectSession.CreateUpdateSearcher()

	$Updates = $UpdateSearcher.Search($null)
	$Updates.Updates | Select-Object Title, Description, RebootRequired, IsDownloaded, IsHidden
}
Invoke-Command -ComputerName 'DC' -ScriptBlock $scriptblock
#endregion

#region Remotely Trigger Update Detection (wuauclt /detectnow)
$scriptblock = {
	$AutoUpdate = New-Object -ComObject 'Microsoft.Update.AutoUpdate'
	$AutoUpdate.DetectNow()
}
Invoke-Command -ComputerName 'DC' -ScriptBlock $scriptblock

$scriptblock = {
	$AutoUpdate = New-Object -ComObject 'Microsoft.Update.AutoUpdate'
	$AutoUpdate.Results
}
Invoke-Command -ComputerName 'DC' -ScriptBlock $scriptblock
#endregion

#region Microsoft Update, Windows Update and WSUS
# Microsoft Updates (normally the default) is MS product updates and everything in Windows Updates
# Windows Updates are Service Packs and core upates but not product updates
$serviceManager = New-Object -Com 'Microsoft.Update.ServiceManager'
$serviceManager.Services | Select-Object Name, ISManaged, IsDefaultAUService, ServiceUrl
#endregion

#region Running as a Job
$scriptBlock = {
	$updateSession = New-Object -ComObject 'Microsoft.Update.Session'
	$updateSearcher = $updateSession.CreateUpdateSearcher()

	If ($updates = ($updateSearcher.Search($Null))) {
		$updates.Updates
	}
}

$Params = @{
	"ComputerName" = 'DC'
	"ScriptBlock"  = $scriptBlock
	"AsJob"        = $true
	"JobName"      = 'DC - Windows Update Query'
}

Invoke-Command @Params

Get-Job -Name 'DC - Windows Update Query' | Wait-Job | Receive-Job
#endregion

#region Parallel Computers
# Clear all previous jobs
Get-Job | Remove-Job

$Computers = @(
	'DC'
	'CLIENT2'
	'WSUS'
	'CLIENT3'
)

$Jobs = @()
$Results = @()

$scriptBlock = {
	$updateSession = New-Object -ComObject 'Microsoft.Update.Session'
	$updateSearcher = $updateSession.CreateUpdateSearcher()

	If ($updates = ($updateSearcher.Search($Null))) {
		$updates.Updates
	}
}

$Computers | Foreach-Object {
	# Not all computers are ICMP ping enabled, but do support PSRemote which is what we need
	Try {
		Test-WSMan -ComputerName $_ -ErrorAction Stop | Out-Null
	} Catch {
		Return
	}

	$Name = "$($_) - Windows Update Query"

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

	$Jobs += Get-Job -Name $Name
}

$Jobs | Wait-Job | Receive-Job | Foreach-Object { $Results += $_ }

$Results | Select-Object PSComputerName, Title | Format-Table -AutoSize
#endregion

#region Wrap it all up into a function
Function Get-WindowsUpdate {
	<#
	.SYNOPSIS
		This function retrieves all Windows Updates meeting the given criteria locally or remotely.
	.DESCRIPTION
		Utilizing the built-in Windows COM objects to interact with the Windows Update service retrieve all Windows Updates meeting the given criteria both on the local system or on a remote system.
	.EXAMPLE
		PS> Get-WindowsUpdate

        Title                                                                                                      LastDeploymentChangeTime
        -----                                                                                                      -------------------
        Windows Malicious Software Removal Tool x64 - February 2019 (KB890830)                                     2/13/2019 12:00:...
        2019-02 Cumulative Update for .NET Framework 3.5 and 4.7.2 for Windows 10 Version 1809 for x64 (KB4483452) 2/13/2019 12:00:...
        2019-02 Cumulative Update for Windows 10 Version 1809 for x64-based Systems (KB4487044)                    2/13/2019 12:00:...
	.PARAMETER Installed
		Return installed updates.
	.PARAMETER Hidden
		Return updates that have been hidden from installation.
	.PARAMETER Assigned
		Return updates that are intended for deployment by Windows Automatic Updates.
	.PARAMETER RebootRequired
        Return updates that require a reboot after installation.
    .PARAMETER ComputerName
        The remote system to retrieve updates from, also aliased as 'Name'.
	#>
	[OutputType([PSCustomObject])]
	[CmdletBinding()]

	Param (
		[Bool]$Installed,
		[Bool]$Hidden,
		[Bool]$Assigned,
		[Bool]$RebootRequired,

		[Parameter(ValueFromPipelineByPropertyName)]
		[Alias('Name')]
		[String]$ComputerName,

		[Switch]$AsJob
	)

	Begin {
		## Create a hashtable to easily "convert" the function paramters to query parts.
		$paramToQueryMap = @{
			Installed      = 'IsInstalled'
			Hidden         = 'IsHidden'
			Assigned       = 'IsAssigned'
			RebootRequired = 'RebootRequired'
		}

		$query = @()

		## Build the query string
		$paramToQueryMap.GetEnumerator() | Foreach-Object {
			If ($PSBoundParameters.ContainsKey($_.Name)) {
				$query += '{0}={1}' -f $paramToQueryMap[$_.Name], [Int](Get-Variable -Name $_.Name).Value
			}
		}

		$query = $query -Join ' AND '
	}

	Process {
		Try {
			## Create the scriptblock we'll use to pass to the remote computer or run locally
			$scriptBlock = {
				param ($Query)

				Write-Verbose "Query is '$Query'"

				$updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
				$updateSearcher = $updateSession.CreateUpdateSearcher()

				If ($result = $updateSearcher.Search($Query)) {
					if ($result.Updates.Count -gt 0) {
						$result.Updates | foreach {
							$update = $_
							$properties = @(
								@{ 'Name' = 'IsDownloaded'; Expression = { $update.IsDownloaded }}
								@{ 'Name' = 'IsInstalled'; Expression = { $update.IsInstalled }}
								@{ 'Name' = 'RebootRequired'; Expression = { $update.RebootRequired }}
								@{ 'Name' = 'ComputerName'; Expression = { $env:COMPUTERNAME }}
								@{ 'Name' = 'KB ID'; Expression = { $_.replace('KB', '') }}
							)
							$_.KBArticleIds | Select-Object -Property $properties
						} 
					}
				}
				if ($Query -eq 'IsInstalled=1') {
					$properties = @(
						@{ 'Name' = 'IsDownloaded'; Expression = { $true }}
						@{ 'Name' = 'IsInstalled'; Expression = { $true }}
						@{ 'Name' = 'RebootRequired'; Expression = { 'Unknown' }}
						@{ 'Name' = 'ComputerName'; Expression = { $env:COMPUTERNAME }}
						@{ 'Name' = 'KB ID'; Expression = { $_.replace('KB', '') }}
					)
					(Get-Hotfix).HotFixId | Select-Object -Property $properties
				}
			}

			## Run the query
			$icmParams = @{
				'ScriptBlock'  = $scriptBlock
				'ArgumentList' = $Query
			}
			if ($PSBoundParameters.ContainsKey('AsJob')) {
				if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
					throw 'This function cannot run as a job on the local comoputer.'
				} else {
					$icmParams.JobName = $ComputerName
					$icmParams.AsJob = $true
				}
			}

			if ($PSBoundParameters.ContainsKey('ComputerName')) {
				$icmParams.ComputerName = $ComputerName
				$icmParams.HideComputerName = $true
			}

			Invoke-Command @icmParams | Select-Object -Property * -ExcludeProperty 'RunspaceId'
		} Catch {
			Throw $_.Exception.Message
		}
	}
}
#endregion

## Function demonstration
Get-WindowsUpdate
Get-WindowsUpdate -ComputerName 'DC'
Get-WindowsUpdate -ComputerName 'DC' -Installed $true

Import-Csv -Path 'C:\computers.txt'

Import-Csv -Path 'C:\computers.txt' | Get-WindowsUpdate

Import-Csv -Path 'C:\computers.txt' | Get-WindowsUpdate -AsJob

Get-Job

Get-Job | Receive-Job