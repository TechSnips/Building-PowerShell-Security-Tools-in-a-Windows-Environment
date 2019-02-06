Function Write-Log {
    [OutputType([void])]
    [CmdletBinding(
        SupportsShouldProcess=$true,
        ConfirmImpact="Low"
    )]

    Param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$LogName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$Source = "General",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Int]$EventId = 1000,

        [ValidateNotNullOrEmpty()]
        [Parameter()]
        [System.Diagnostics.EventLogEntryType]$EntryType = [System.Diagnostics.EventLogEntryType]::Information,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Message
    )

    Process {
        $EventSession        = [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession
        $EventLogNames       = $EventSession.GetLogNames()
        $EventProviderNames  = $EventSession.GetProviderNames()
        $EventLogMessagePath = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\EventLogMessages.dll'
        $maxMessageLength    = 31837

        If ($EventLogNames -NotContains $LogName) {
            If ($PSCmdlet.ShouldProcess($LogName,'Creating Log')) {
                Try {
                    New-EventLog -LogName $LogName -Source $Source -ErrorAction Stop | Out-Null
                } Catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
        }

        If ($EventProviderNames -NotContains $Source) {
            If (Test-Path $EventLogMessagePath) {
                If ($PSCmdlet.ShouldProcess($Source,'Creating Provider with Message Resource File')) {
                    Try {
                        $Params = @{
                            'LogName'             = $LogName
                            'Source'              = $Source
                            'MessageResourceFile' = $EventLogMessagePath
                            'ErrorAction'         = 'Stop'
                        }

                        New-EventLog @Params | Out-Null
                    } Catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
            } ELse {
                If ($PSCmdlet.ShouldProcess($Source,'Creating Provider')) {
                    Try {
                        $Params = @{
                            'LogName'             = $LogName
                            'Source'              = $Source
                            'ErrorAction'         = 'Stop'
                        }

                        New-EventLog @Params | Out-Null
                    } Catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
            }
        }

        If ($PSCmdlet.ParameterSetName -EQ 'Error') {
            $Message = $ErrorRecord.Exception.Message
        }

        If ($message.Length -GT $maxMessageLength) {
            Write-Warning "Message length [$($message.Length)] is too long, truncating to max length of $maxMessageLength"
            $Message = $message.Substring(0, $maxMessageLength)
        }
        If ($PSCmdlet.ShouldProcess($Message,'Writing Event')) {
            Try {
                $Params = @{
                    'LogName'     = $LogName
                    'Source'      = $Source
                    'EventId'     = $EventId
                    'EntryType'   = $EntryType
                    'Message'     = $Message
                    'ErrorAction' = 'Continue'
                }

                Write-EventLog @Params | Out-Null
            } Catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
	}
}