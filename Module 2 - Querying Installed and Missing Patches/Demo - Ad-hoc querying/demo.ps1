## Scenario: Query updates different ways on a local computer

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
$updates.Update | Select-Object Title, LastDeploymentChangeTime
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
$InstalledUpdates     = $UpdateObjectSearcher.Search("IsInstalled=1")

$InstalledUpdates.Categories | Select-Object -ExpandProperty Name

$InstalledUpdates | Where-Object $InstalledUpdates.Categories.Name -EQ 'Definition Updates'

# $SearchResults.RootCategories.Item($UpdateID).Updates
#endregion

#region Wrap it all up into a function

Function Get-WindowsUpdate {
	[OutputType([System.Management.Automation.PSObject])]
	[CmdletBinding()]
    
	Param (
		[Switch]$Installed,
		[Switch]$Hidden,
		[Switch]$Assigned,
		[Switch]$RebootRequired,
		[Switch]$PassThru
	)

	Begin {
		$conversion = @{
			Installed      = 'IsInstalled'
			Hidden         = 'IsHidden'
			Assigned       = 'IsAssigned'
			RebootRequired = 'RebootRequired'
		}

		$updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
		$updateSearcher = $updateSession.CreateUpdateSearcher()

		$query = @()
	}

	Process {
		$conversion.GetEnumerator() | Foreach-Object {
			$condition = Get-Variable $_.Key -Scope Local

			If ($condition -And $condition.Value -NE $false) {
				$query += '{0}={1}' -f $conversion[$condition.Name], [Int][Bool]$condition.Value
			}
		}

		$query = $query -Join ' AND '
		Write-Verbose "Query is '$query'"

		Try {
			$updates = ($updateSearcher.Search($query))

			If ($updates) {
				$updates = $updates.Updates

				$updates | Select-Object Title, LastDeploymentChangeTime

				If ($PassThru) {
					$updates
				}
			}
		} Catch {
			Throw $_.Exception.Message
		}
	}
}
#endregion