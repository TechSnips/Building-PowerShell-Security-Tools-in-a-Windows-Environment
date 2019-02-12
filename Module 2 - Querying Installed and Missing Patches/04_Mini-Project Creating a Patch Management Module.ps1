#region Get-WindowsUpdate Function
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

                $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
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

#region Install-WindowsUpdate
Function Install-WindowsUpdate {
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]

    Param (
        $Updates,

        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String]$ComputerName,

        [Switch]$PassThru
    )

    Process {

    }
}
#endregion

#region Start-WindowsUpdateDownload
Function Start-WindowsUpdateDownload {
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]

    Param (
        $Updates,

        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String]$ComputerName,

        [Switch]$PassThru
    )

    Process {
        Try {
            $scriptBlock = {
                Param (
                    $PassThru
                )

                Write-Verbose "PassThru is '$PassThru'"

                $updateSession  = New-Object -ComObject 'Microsoft.Update.Session'
                $updateSearcher = $updateSession.CreateUpdateSearcher()

                If ($updates = ($updateSearcher.Search($null))) {
                    $downloader         = $updateSession.CreateUpdateDownloader()
                    $downloader.Updates = $updates.updates
                    $downloadResult     = $downloader.Download()
                }
            }

            If ($ComputerName) {
                Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $PassThru |
                    Select-Object PSRemoteComputer, Title, LastDeploymentChangeTime
            }
            Else {
                & $scriptBlock $PassThru
            }
        }
        Catch {
            Throw $_.Exception.Message
        }
    }
}
#endregion