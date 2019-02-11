#region Find Updates
$UpdateObjectSession = New-Object -ComObject 'Microsoft.Update.Session'
$UpdateSearcher      = $UpdateObjectSession.CreateUpdateSearcher()

$Updates = $UpdateSearcher.Search($null)
$Updates.Updates | Select-Object Title, Description, RebootRequired, IsDownloaded, IsHidden
#endregion

#region Find Installed Updates
$Updates = $UpdateSearcher.Search('IsInstalled=1')
$Updates.Updates | Select-Object Title, Description, RebootRequired, IsDownloaded, IsHidden
#endregion

#region Find Updates Required a Reboot
$Updates = $UpdateSearcher.Search('RebootRequired=1')
$Updates.Updates | Select-Object Title, Description, RebootRequired, IsDownloaded, IsHidden
#endregion

#region Find Hidden Updates
$Updates = $UpdateSearcher.Search('IsHidden=1')
$Updates.Updates | Select-Object Title, Description, RebootRequired, IsDownloaded, IsHidden
#endregion

#region Find Assigned Updates
# These are updates that are intended for deployment by Windows Automatic Updates
$Updates = $UpdateSearcher.Search('IsAssigned=1')
$Updates.Updates | Select-Object Title, Description, RebootRequired, IsDownloaded, IsHidden
#endregion

#region Multiple Conditions
$Updates = $UpdateSearcher.Search('IsInstalled=0 AND RebootRequired=1')
$Updates.Updates | Select-Object Title, Description, RebootRequired, IsDownloaded, IsHidden
#endregion

#region Search by Category
$UpdateObjectSearcher = New-Object -ComObject 'Microsoft.Update.Searcher'
$InstalledUpdates     = $UpdateObjectSearcher.Search("IsInstalled=1")

$InstalledUpdates.Updates | Foreach-Object {
    $Result = $_.Categories | Where-Object Name -EQ 'Definition Updates'

    If ($Result) {
        $_
    }
} | Select-Object Title, LastDeploymentChangeTime
#endregion

#region Get Updates on a Remote Computer (PSRemoting)
$scriptblock = {
	$UpdateObjectSession = New-Object -ComObject 'Microsoft.Update.Session'
	$UpdateSearcher      = $UpdateObjectSession.CreateUpdateSearcher()

	$Updates = $UpdateSearcher.Search($null)
	$Updates.Updates | Select-Object Title, Description, RebootRequired, IsDownloaded, IsHidden
}

Invoke-Command -ComputerName 'DC' -ScriptBlock $scriptblock
#endregion

#region Microsoft Update, Windows Update and WSUS
# Microsoft Updates (normally the default) is MS product updates and everything in Windows Updates
# Windows Updates are Service Packs and core dupates but not product updates
$serviceManager = New-Object -Com 'Microsoft.Update.ServiceManager'
$serviceManager.Services | Select-Object Name, ISManaged, IsDefaultAUService,ServiceUrl
#endregion

#region Get-WindowsUpdate
Function Get-WindowsUpdate {
	[OutputType([System.Management.Automation.PSObject])]
	[CmdletBinding()]

    Param (
		[Switch]$Installed,
        [Switch]$Hidden,
        [Switch]$Assigned,
        [Switch]$RebootRequired,

        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String]$ComputerName,

        [Switch]$PassThru
    )

    Begin {
        $conversion = @{
            Installed      = 'IsInstalled'
            Hidden         = 'IsHidden'
            Assigned       = 'IsAssigned'
            RebootRequired = 'RebootRequired'
        }

        $Query = @()
    }

	Process {
        $conversion.GetEnumerator() | Foreach-Object {
            $condition = Get-Variable $_.Key -Scope Local

            If ($condition -And $condition.Value -NE $false) {
                $Query += '{0}={1}' -f $conversion[$condition.Name], [Int][Bool]$condition.Value
            }
        }

        $Query = $Query -Join ' AND '

        Try {
            $scriptBlock = {
                Param (
                    $Query,
                    $PassThru
                )

                Write-Verbose "Query is '$Query'"
                Write-Verbose "PassThru is '$PassThru'"

                $updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
                $updateSearcher = $updateSession.CreateUpdateSearcher()

                If ($updates = ($updateSearcher.Search($Query))) {
                    If ($PassThru) {
                        $updates.Updates
                    } Else {
                        $updates.Updates | Select-Object Title, LastDeploymentChangeTime
                    }
                }
            }

            If ($ComputerName) {
		            Write-Verbose "Query is '$Query'"
                Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $Query, $PassThru |
                    Select-Object PSRemoteComputer, Title, LastDeploymentChangeTime
            } Else {
                & $scriptBlock $Query $PassThru
            }
        } Catch {
            Throw $_.Exception.Message
        }
	}
}
#endregion