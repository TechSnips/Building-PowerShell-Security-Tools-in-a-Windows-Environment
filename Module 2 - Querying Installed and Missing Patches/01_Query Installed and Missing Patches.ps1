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
# Windows Updates are Service Packs and core dupates but not product updates
$serviceManager = New-Object -Com 'Microsoft.Update.ServiceManager'
$serviceManager.Services | Select-Object Name, ISManaged, IsDefaultAUService, ServiceUrl
#endregion

#region Wrap it all up into a function

Function Get-WindowsUpdate {
	<#
        .SYNOPSIS
            This function queries a local or remote computers for Windows patches.
        .PARAMETER Installed
            A switch parameter to limit updates returned to only installed updates.
        .PARAMETER Hidden
            A switch parameter to limit updates returned to only hidden updates.
        .PARAMETER Assigned
            A switch parameter to limit updates returned to only assigned updates.
        .PARAMETER RebootRequired
            A switch parameter to limit updates returned to only those that will require a reboot after installation.
        .PARAMETER ComputerName
            A string parameter representing a remote computer to query. If this is not provided, this function will query
            updates on the local computer.
    
        .EXAMPLE
            PS> Get-WindowsUpdate -Installed -Hidden -ComputerName SRV1

            This example will attempt to find all updates that are installed and hidden on the remote SRV1 computer.
    
    #>
	[OutputType([pscustomobject])]
	[CmdletBinding()]

	Param (
		[Switch]$Installed,
		[Switch]$Hidden,
		[Switch]$Assigned,
		[Switch]$RebootRequired,

		[Parameter(ValueFromPipeline)]
		[Alias('Name')]
		[ValidateNotNullOrEmpty()]
		[String]$ComputerName
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
			if ($PSBoundParameters.ContainsKey($_.Name)) {
				$query += '{0}=1' -f $paramToQueryMap[$_.Name]
			}
		}

		$query = $query -Join ' AND '

		try {

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

				if ($updates = ($updateSearcher.Search($Query))) {
					$updates.Updates | Select-Object Title, LastDeploymentChangeTime
				}
			}

			if ($PSBoundParameters.ContainsKey('ComputerName')) {
				Write-Verbose "Query is '$Query'"
				Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $Query |
					Select-Object PSComputerName, Title, LastDeploymentChangeTime
			} else {
				& $scriptBlock $Query
			}
		} catch {
			throw $_.Exception.Message
		}
	}
}
#endregion

## Function demonstration
Get-WindowsUpdate
Get-WindowsUpdate -ComputerName DC
Get-WindowsUpdate -ComputerName DC -Installed

Get-AdComputer | Get-WindowsUpdate
