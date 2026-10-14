<#
.SYNOPSIS
Synchronizes installed PowerShell modules with a ProGet PowerShell feed.

.DESCRIPTION
Queries a registered PowerShell repository, selects the newest semantic version of each matching
module, compares it with the newest locally installed version, and installs only missing modules or
upgrades after ShouldProcess approval.

By default, Tier is resolved through Resolve-ProGetFeedFromSettings. Repository and FeedUrl may be
supplied explicitly to target any registered ProGet PowerShell feed from any host. The function never
registers a repository or changes repository trust.

.PARAMETER Tier
ATAP promotion tier used when Repository is omitted. The default is Stable.

.PARAMETER Repository
Explicit registered PSRepository name. Supplying this bypasses tier-based feed resolution.

.PARAMETER FeedUrl
Explicit ProGet feed base URI. When Repository is explicit and FeedUrl is omitted, the registered
repository SourceLocation is used. A validated install requires an absolute HTTPS URI.

.PARAMETER Filter
Wildcard module-name filter passed to Find-Module. The default is ATAP.*.

.PARAMETER Scope
Installation scope used by Install-Module. UseValidatedInstaller requires AllUsers.

.PARAMETER UseValidatedInstaller
Uses Install-ATAPModuleAllUsers instead of Install-Module.

.PARAMETER ExpectedSha256ByModule
Hashtable keyed by module name containing the 64-character hexadecimal package hash required by
UseValidatedInstaller.

.OUTPUTS
System.Management.Automation.PSCustomObject. One result per module with its installed and ProGet
versions, status, action, repository, tier, feed URI, and any per-module error.

.EXAMPLE
Sync-ProGetPowerShellModules -Tier Stable -WhatIf

Previews synchronization against the configured stable feed.

.EXAMPLE
Sync-ProGetPowerShellModules -Repository 'customer-powershell' `
  -FeedUrl 'https://proget.example.test/nuget/customer-powershell/' -Scope CurrentUser

Synchronizes from an explicitly selected registered ProGet feed on any host.

.EXAMPLE
$pins = @{ 'ATAP.Utilities.BuildTooling.Common.PowerShell' = ('A' * 64) }
Sync-ProGetPowerShellModules -Repository 'powershellget-stable' `
  -FeedUrl 'https://proget.example.test/nuget/powershellget-stable/' `
  -UseValidatedInstaller -ExpectedSha256ByModule $pins

Uses the hash-pinned AllUsers installer.

.NOTES
Task 15.195. This file contains only the eponymous function definition and performs no work when the
module dot-sources it.

.LINK
Install-ATAPModuleAllUsers

.LINK
Resolve-ProGetFeedFromSettings
#>
function Sync-ProGetPowerShellModules {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Tier = 'Stable',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Repository,

    [Parameter()]
    [ValidateScript({
      if ([string]::IsNullOrWhiteSpace($_)) {
        return $true
      }
      $uri = [uri]$_
      if (-not $uri.IsAbsoluteUri) {
        throw 'FeedUrl must be an absolute URI.'
      }
      return $true
    })]
    [string]$FeedUrl,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Filter = 'ATAP.*',

    [Parameter()]
    [ValidateSet('AllUsers', 'CurrentUser')]
    [string]$Scope = 'AllUsers',

    [Parameter()]
    [switch]$UseValidatedInstaller,

    [Parameter()]
    [hashtable]$ExpectedSha256ByModule = @{}
  )

  begin {
    $fn = 'Sync-ProGetPowerShellModules'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if ($UseValidatedInstaller -and $Scope -ne 'AllUsers') {
      throw 'UseValidatedInstaller requires Scope AllUsers.'
    }
    if ($PSBoundParameters.ContainsKey('FeedUrl') -and -not $PSBoundParameters.ContainsKey('Repository')) {
      throw 'Repository must be supplied when FeedUrl is explicit.'
    }

    foreach ($requiredCommand in @('Find-Module', 'Get-PSRepository', 'Get-Module')) {
      if (-not (Get-Command -Name $requiredCommand -ErrorAction SilentlyContinue)) {
        throw "Required command '$requiredCommand' is unavailable."
      }
    }
    if (-not $PSBoundParameters.ContainsKey('Repository') -and -not (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -ErrorAction SilentlyContinue)) {
      throw "Required command 'Resolve-ProGetFeedFromSettings' is unavailable."
    }
    if ($UseValidatedInstaller -and -not (Get-Command -Name 'Install-ATAPModuleAllUsers' -ErrorAction SilentlyContinue)) {
      throw "Required command 'Install-ATAPModuleAllUsers' is unavailable."
    }
    if (-not $UseValidatedInstaller -and -not (Get-Command -Name 'Install-Module' -ErrorAction SilentlyContinue)) {
      throw "Required command 'Install-Module' is unavailable."
    }

    $convertToSemanticVersion = {
      param(
        [Parameter(Mandatory)]
        [object]$Value,

        [Parameter(Mandatory)]
        [string]$Context
      )

      $versionText = [string]$Value
      try {
        return [System.Management.Automation.SemanticVersion]$versionText
      }
      catch {
        throw "Invalid semantic version '$versionText' for $Context."
      }
    }

    try {
      if ($PSBoundParameters.ContainsKey('Repository')) {
        $resolvedRepositoryName = $Repository
        $resolvedTier = 'Explicit'
        $registeredRepository = Get-PSRepository -Name $resolvedRepositoryName -ErrorAction SilentlyContinue
        if (-not $registeredRepository) {
          throw "PSRepository '$resolvedRepositoryName' is not registered. Configure it before synchronizing modules."
        }
        if (-not $PSBoundParameters.ContainsKey('FeedUrl')) {
          $FeedUrl = [string]$registeredRepository.SourceLocation
        }
      }
      else {
        $feed = Resolve-ProGetFeedFromSettings -FeedType 'powershellget' -Tier $Tier
        $resolvedRepositoryName = [string]$feed.FeedName
        $resolvedTier = [string]$feed.Tier
        $registeredRepository = Get-PSRepository -Name $resolvedRepositoryName -ErrorAction SilentlyContinue
        if (-not $registeredRepository) {
          throw "PSRepository '$resolvedRepositoryName' is not registered. Configure it before synchronizing modules."
        }
        $FeedUrl = [string]$feed.Uri
        if ([string]::IsNullOrWhiteSpace($FeedUrl)) {
          $FeedUrl = [string]$feed.EndpointUri
        }
      }

      if ([string]::IsNullOrWhiteSpace($FeedUrl)) {
        throw "Repository '$resolvedRepositoryName' has no usable feed URI."
      }
      if ($UseValidatedInstaller -and ([uri]$FeedUrl).Scheme -ne 'https') {
        throw 'UseValidatedInstaller requires FeedUrl to use HTTPS.'
      }

      $feedModules = @(Find-Module -Repository $resolvedRepositoryName -Name $Filter -ErrorAction Stop)
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message
      throw
    }
  }

  process {
    $newestFeedModules = @(
      $feedModules |
        Group-Object -Property Name |
        ForEach-Object {
          $_.Group |
            Sort-Object -Property @{ Expression = { & $convertToSemanticVersion -Value $_.Version -Context "feed module '$($_.Name)'" }; Descending = $true } |
            Select-Object -First 1
        }
    )

    foreach ($module in $newestFeedModules) {
      $moduleName = [string]$module.Name
      $feedVersion = & $convertToSemanticVersion -Value $module.Version -Context "feed module '$moduleName'"
      $installedModule = Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
      $installedVersion = if ($installedModule) {
        & $convertToSemanticVersion -Value $installedModule.Version -Context "installed module '$moduleName'"
      }
      else {
        $null
      }

      $status = if ($null -eq $installedVersion) {
        'Missing'
      }
      elseif ($feedVersion -gt $installedVersion) {
        'UpgradeAvailable'
      }
      else {
        'UpToDate'
      }
      $actionTaken = 'Skipped'
      $errorText = $null

      if ($status -ne 'UpToDate') {
        $target = if ($null -eq $installedVersion) {
          "$moduleName (not installed -> $feedVersion)"
        }
        else {
          "$moduleName ($installedVersion -> $feedVersion)"
        }

        if ($PSCmdlet.ShouldProcess($target, "Install from $resolvedRepositoryName")) {
          try {
            if ($UseValidatedInstaller) {
              if (-not [string]::IsNullOrWhiteSpace($feedVersion.PreReleaseLabel)) {
                throw "UseValidatedInstaller does not support prerelease version '$feedVersion' for module '$moduleName'."
              }
              $expectedSha256 = [string]$ExpectedSha256ByModule[$moduleName]
              if ($expectedSha256 -notmatch '^[0-9A-Fa-f]{64}$') {
                throw "A valid SHA-256 pin is required for module '$moduleName' when UseValidatedInstaller is selected."
              }
              $installResult = Install-ATAPModuleAllUsers -ModuleName $moduleName `
                -RequiredVersion ([string]$module.Version) `
                -Repository $resolvedRepositoryName `
                -FeedUrl $FeedUrl `
                -ExpectedSha256 $expectedSha256 `
                -Confirm:$false
              if ($installResult.ExitStatus -ne 0) {
                throw "Validated installation failed for '$moduleName': $($installResult.ErrorText)"
              }
            }
            else {
              $installParameters = @{
                Name            = $moduleName
                RequiredVersion = [string]$module.Version
                Repository      = $resolvedRepositoryName
                Scope           = $Scope
                Force           = $true
                AllowClobber    = $true
                ErrorAction     = 'Stop'
              }
              if (-not [string]::IsNullOrWhiteSpace($feedVersion.PreReleaseLabel)) {
                $installParameters.AllowPrerelease = $true
              }
              Install-Module @installParameters
            }
            $actionTaken = 'Installed'
          }
          catch {
            $actionTaken = 'Failed'
            $errorText = $_.Exception.Message
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorText
          }
        }
        else {
          $actionTaken = 'WhatIf'
        }
      }

      [PSCustomObject]@{
        ModuleName       = $moduleName
        InstalledVersion = if ($null -eq $installedVersion) { $null } else { [string]$installedVersion }
        ProGetVersion    = [string]$feedVersion
        Status           = $status
        ActionTaken      = $actionTaken
        Repository       = $resolvedRepositoryName
        Tier             = $resolvedTier
        FeedUrl          = $FeedUrl
        ErrorText        = $errorText
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
