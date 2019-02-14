# Error Reference
https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-error-reference

$objects = Get-WMIObject Win32_ClassicCOMClassSetting
$objects | Where-Object ProgId -Match 'Microsoft.Update' | Select-Object ProgId

<#
Microsoft.Update.UpdateColl.1
Microsoft.Update.InstallationAgent.1
Microsoft.Update.Session.1
Microsoft.Update.Downloader.1
Microsoft.Update.WebProxy.1
Microsoft.Update.StringColl.1
Microsoft.Update.Searcher.1
Microsoft.Update.AutoUpdate.1
Microsoft.Update.SystemInfo.1
Microsoft.Update.AgentInfo.1
Microsoft.Update.Installer.1
Microsoft.Update.ServiceManager.1
#>

$updateColl     = New-Object -Com 'Microsoft.Update.UpdateColl'
$stringColl     = New-Object -Com 'Microsoft.Update.StringColl'

$installAgent   = New-Object -Com 'Microsoft.Update.InstallationAgent'
$session        = New-Object -Com 'Microsoft.Update.Session'
$downloader     = New-Object -Com 'Microsoft.Update.Downloader'
$webProxy       = New-Object -Com 'Microsoft.Update.WebProxy'
$searcher       = New-Object -Com 'Microsoft.Update.Searcher'
$autoUpdate     = New-Object -Com 'Microsoft.Update.AutoUpdate'
$systemInfo     = New-Object -Com 'Microsoft.Update.SystemInfo'
$agentInfo      = New-Object -Com 'Microsoft.Update.AgentInfo'
$installer      = New-Object -Com 'Microsoft.Update.Installer'
$serviceManager = New-Object -Com 'Microsoft.Update.ServiceManager'

<#
# InstallAgent
RecordInstallationResult Method     void RecordInstallationResult (string, int, IStringCollection)

# Session
CreateUpdateDownloader     Method     IUpdateDownloader CreateUpdateDownloader ()
CreateUpdateInstaller      Method     IUpdateInstaller CreateUpdateInstaller ()
CreateUpdateSearcher       Method     IUpdateSearcher CreateUpdateSearcher ()
CreateUpdateServiceManager Method     IUpdateServiceManager2 CreateUpdateServiceManager ()
QueryHistory               Method     IUpdateHistoryEntryCollection QueryHistory (string, int, int)
ClientApplicationID        Property   string ClientApplicationID () {get} {set}
ReadOnly                   Property   bool ReadOnly () {get}
UserLocale                 Property   uint UserLocale () {get} {set}
WebProxy                   Property   IWebProxy WebProxy () {get} {set}

# Downloader
BeginDownload       Method     IDownloadJob BeginDownload (IUnknown, IUnknown, Variant)
Download            Method     IDownloadResult Download ()
EndDownload         Method     IDownloadResult EndDownload (IDownloadJob)
ClientApplicationID Property   string ClientApplicationID () {get} {set}
IsForced            Property   bool IsForced () {get} {set}
Priority            Property   DownloadPriority Priority () {get} {set}
Updates             Property   IUpdateCollection Updates () {get} {set}

# WebProxy
PromptForCredentials Method     void PromptForCredentials (IUnknown, string)
SetPassword          Method     void SetPassword (string)
Address              Property   string Address () {get} {set}
AutoDetect           Property   bool AutoDetect () {get} {set}
BypassList           Property   IStringCollection BypassList () {get} {set}
BypassProxyOnLocal   Property   bool BypassProxyOnLocal () {get} {set}
ReadOnly             Property   bool ReadOnly () {get}
UserName             Property   string UserName () {get} {set}

# Searcher
BeginSearch                         Method     ISearchJob BeginSearch (string, IUnknown, Variant)
EndSearch                           Method     ISearchResult EndSearch (ISearchJob)
EscapeString                        Method     string EscapeString (string)
GetTotalHistoryCount                Method     int GetTotalHistoryCount ()
QueryHistory                        Method     IUpdateHistoryEntryCollection QueryHistory (int, int)
Search                              Method     ISearchResult Search (string)
CanAutomaticallyUpgradeService      Property   bool CanAutomaticallyUpgradeService () {get} {set}
ClientApplicationID                 Property   string ClientApplicationID () {get} {set}
IgnoreDownloadPriority              Property   bool IgnoreDownloadPriority () {get} {set}
IncludePotentiallySupersededUpdates Property   bool IncludePotentiallySupersededUpdates () {get} {set}
Online                              Property   bool Online () {get} {set}
SearchScope                         Property   SearchScope SearchScope () {get} {set}
ServerSelection                     Property   ServerSelection ServerSelection () {get} {set}
ServiceID                           Property   string ServiceID () {get} {set}

# AutoUpdate
DetectNow          Method     void DetectNow ()
EnableService      Method     void EnableService ()
Pause              Method     void Pause ()
Resume             Method     void Resume ()
ShowSettingsDialog Method     void ShowSettingsDialog ()
Results            Property   IAutomaticUpdatesResults Results () {get}
ServiceEnabled     Property   bool ServiceEnabled () {get}
Settings           Property   IAutomaticUpdatesSettings Settings () {get}

$autoUpdate.Settings
NotificationLevel         : 4
ReadOnly                  : False
Required                  : True
ScheduledInstallationDay  : 0
ScheduledInstallationTime : 3
IncludeRecommendedUpdates : True
NonAdministratorsElevated : True
FeaturedUpdatesEnabled    : False

# SystemInfo
OemHardwareSupportLink Property   string OemHardwareSupportLink () {get}
RebootRequired         Property   bool RebootRequired () {get}

# AgentInfo
GetInfo Method     Variant GetInfo (Variant)

$agentInfo.GetInfo('ProductVersionString')
$agentInfo.GetInfo('ApiMajorVersion')
$agentInfo.GetInfo('ApiMinorVersion')

# Installer
BeginInstall                     Method     IInstallationJob BeginInstall (IUnknown, IUnknown, Variant)
BeginUninstall                   Method     IInstallationJob BeginUninstall (IUnknown, IUnknown, Variant)
EndInstall                       Method     IInstallationResult EndInstall (IInstallationJob)
EndUninstall                     Method     IInstallationResult EndUninstall (IInstallationJob)
Install                          Method     IInstallationResult Install ()
RunWizard                        Method     IInstallationResult RunWizard (string)
Uninstall                        Method     IInstallationResult Uninstall ()
AllowSourcePrompts               Property   bool AllowSourcePrompts () {get} {set}
ClientApplicationID              Property   string ClientApplicationID () {get} {set}
ForceQuiet                       Property   bool ForceQuiet () {get} {set}
IsBusy                           Property   bool IsBusy () {get}
IsForced                         Property   bool IsForced () {get} {set}
parentWindow                     Property   IUnknown parentWindow () {get} {set}
RebootRequiredBeforeInstallation Property   bool RebootRequiredBeforeInstallation () {get}
Updates                          Property   IUpdateCollection Updates () {get} {set}

# Service Manager
AddScanPackageService    Method     IUpdateService AddScanPackageService (string, string, int)
AddService               Method     IUpdateService AddService (string, string)
AddService2              Method     IUpdateServiceRegistration AddService2 (string, int, string)
QueryServiceRegistration Method     IUpdateServiceRegistration QueryServiceRegistration (string)
RegisterServiceWithAU    Method     void RegisterServiceWithAU (string)
RemoveService            Method     void RemoveService (string)
SetOption                Method     void SetOption (string, Variant)
UnregisterServiceWithAU  Method     void UnregisterServiceWithAU (string)
ClientApplicationID      Property   string ClientApplicationID () {get} {set}
Services                 Property   IUpdateServiceCollection Services () {get}
#>