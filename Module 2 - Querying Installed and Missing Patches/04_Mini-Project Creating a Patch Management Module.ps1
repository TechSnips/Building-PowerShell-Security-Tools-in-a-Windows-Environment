#region Get-WindowsUpdate Function
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

                $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
                $updateSearcher = $updateSession.CreateUpdateSearcher()

                If ($updates = ($updateSearcher.Search($Query))) {
                    $updates.Updates
                }
            }

            ## Run the query
            $icmParams = @{
                'ScriptBlock'  = $scriptBlock
                'ArgumentList' = $Query
            }

            If ($PSBoundParameters.ContainsKey('ComputerName')) {
                $icmParams.ComputerName = $ComputerName
            }

            Invoke-Command @icmParams
        }
        Catch {
            Throw $_.Exception.Message
        }
    }
}
#endregion

#region Install-WindowsUpdate
Function Install-WindowsUpdate {
    <#
	.SYNOPSIS
		Install available updates for Windows.
	.DESCRIPTION
		Utilizing the built-in Windows COM objects to interact with the Windows Update service install available updates for Windows.
    .EXAMPLE
        PS> Install-WindowsUpdate
        WARNING: Reboot required
	.PARAMETER Updates
		Return installed updates.
	.PARAMETER ComputerName
		The remote system to retrieve updates from, also aliased as 'Name'.
	.PARAMETER PassThru
		Pass the unfiltered update objects to the pipeline.
	#>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]

    Param (
        $Updates,

        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias("Name")]
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

                    If ($downloadResult.ResultCode -ne 2) {
                        Exit $downloadResult.ResultCode;
                    }

                    $installer         = New-Object -ComObject 'Microsoft.Update.Installer'
                    $installer.Updates = $updates.updates
                    $installResult     = $installer.Install()

                    If ($installResult.RebootRequired) {
                        Write-Warning "Reboot required"

                        If ($PassThru) {
                            $Updates.Updates
                        }
                    }
                    Else {
                        If ($PassThru) {
                            $Updates.Updates
                        } Else {
                            $installResult.ResultCode
                        }
                    }
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

#region Start-WindowsUpdateDownload
Function Start-WindowsUpdateDownload {
    <#
	.SYNOPSIS
		Start the download for available Windows Updates
	.DESCRIPTION
		Utilizing the built-in Windows COM objects to interact with the Windows Update service start the download for the available updates.
    .EXAMPLE
        PS> Start-WindowsUpdateDownload

	.PARAMETER Updates
		Updates to start the download.
	.PARAMETER ComputerName
		The remote system to retrieve updates from, also aliased as 'Name'.
	.PARAMETER PassThru
		Pass the unfiltered update objects to the pipeline.
	#>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]

    Param (
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
                    $downloader.Updates = $Updates.Updates
                    $downloadResult     = $downloader.Download()

                    If ($PassThru) {
                        $Updates.Updates
                    }
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

#region Out-WindowsUpdateReport
Function Out-WindowsUpdateReport {
    <#
	.SYNOPSIS
		This function will output all piped in updates, remote or local, to an HTML page saved on disk.
	.DESCRIPTION
		Output the results of gathering Windows Updates to an HTML file on disk.
	.EXAMPLE
		PS> Get-WindowsUpdate | Out-WindowsUpdateReport
	.PARAMETER FilePath
		Location to output the report.
	.PARAMETER UpdateResult
		Updates to export.
	#>
    [OutputType('void')]
    [CmdletBinding()]
    Param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$FilePath = '.\WindowsUpdates.html',

        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$UpdateResult
    )

    begin {
        $ErrorActionPreference = 'Stop'

        $header = @"
<!doctype html>
<html lang='en'>
<head>
    <style type='text/css'>.updates{empty-cells:show;border:1px solid #cbcbcb;border-collapse:collapse;border-spacing:0}.updates thead{background-color:#e0e0e0;color:#000;text-align:left;vertical-align:bottom}.updates td,.updates th{padding:.5em 1em;border-width:0 0 1px;border-bottom:1px solid #cbcbcb;margin:0}.updates td:first-child,.updates th:first-child{border-left-width:0}.updates th{border-width:0 0 1px;border-bottom:1px solid #cbcbcb}.updates .installed{background-color:#a5d6a7;color:#030}.updates .notinstalled{background-color:#ef9a9a;color:#7f0000}</style>
</head>
<body>
    <table class='updates'>
        <thead>
            <tr>
                <th>Computer</th>
                <th>Title</th>
                <th>Description</th>
                <th>IsInstalled</th>
            </tr>
        </thead>
        <tbody>
"@

        $body = ""

        $footer = @"
        </tbody>
    </table>
</body>
</html>
"@
    }

    Process {
        If ($UpdateResult.PSComputerName) {
            $computerName = $UpdateResult.PSComputerName
        }
        Else {
            $computerName = 'Local'
        }

        If ($UpdateResult.IsInstalled) {
            $class = 'installed'
        }
        Else {
            $class = 'notinstalled'
        }

        $body += "`t`t`t<tr class='$class'><td>$($computerName)</td><td>$($UpdateResult.Title)</td><td>$($UpdateResult.Description)</td><td>$($UpdateResult.IsInstalled)</td></tr>`r`n"
    }
    End {
        $html = $header + $body + $footer
        $html | Out-File -FilePath $FilePath -Force
    }
}
#endregion