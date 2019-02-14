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
	"JobName"      = "$ComputerName - Windows Update Query"
}

Invoke-Command @Params

$Result = Get-Job | Where-Object Name -Match "Windows Update Query" | Select-Object -Last 1 | Wait-Job | Receive-Job

$Result
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
	}

	Process {
		## Build the query string
		$paramToQueryMap.GetEnumerator() | Foreach-Object {
			If ($PSBoundParameters.ContainsKey($_.Name)) {
				$query += '{0}={1}' -f $paramToQueryMap[$_.Name], [Int](Get-Variable -Name $_.Name).Value
			}
		}

		$query = $query -Join ' AND '

		Try {
			## Create the scriptblock we'll use to pass to the remote computer or run locally
			$scriptBlock = {
				param (
					$Query,
					$PassThru
				)

				Write-Verbose "Query is '$Query'"
				Write-Verbose "PassThru is '$PassThru'"

				$updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
				$updateSearcher = $updateSession.CreateUpdateSearcher()

				If ($updates = ($updateSearcher.Search($Query))) {
					$updates.Updates
				}
			}

			## Run the query
			$icmParams = @{
				'ScriptBlock'  = $scriptBlock
                'ArgumentList' = $Query
                'Job'          = $AsJob.IsPresent
            }

			If ($PSBoundParameters.ContainsKey('ComputerName')) {
				$icmParams.ComputerName = $ComputerName
			}

			Invoke-Command @icmParams
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
Get-WindowsUpdate | Select-Object -Property Title, Description, IsInstalled | Format-List

Import-Csv -Path 'C:\computers.txt'

Import-Csv -Path 'C:\computers.txt' | Get-WindowsUpdate