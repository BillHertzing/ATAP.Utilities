#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Installs one or more ATAP PowerShell modules globally (all users) from the
  ProGet powershellget-stable feed, registering and trusting the repository
  first when needed.

.DESCRIPTION
  Performs the following steps for each module in -ModuleNames:
    1. Resolves and validates the ProGet feed URI from parameters,
       environment variables, $global:settings, or a built-in default.
    2. Verifies the feed is reachable.
    3. Ensures the 'powershellget-stable' PSRepository is registered and trusted,
       registering it when absent or upgrading its trust when Untrusted.
    4. Warns if the ProGet repository is ordered after PSGallery
       (PSRepositories are searched in registration order).
    5. Confirms the module exists on the feed via Find-Module.
    6. Installs the latest version with Install-Module -Scope AllUsers.

  The URI is composed from the resolved scheme, host, and port exactly as the
  IAC fragment HostSettings.IAC.Fragment.PackageRepositories.ProGetFeeds.ps1
  does, using [UriBuilder]:
      {ProGetScheme}://{ProGetHost}:{ProGetPort}/nuget/powershellget-stable/

  Parameter resolution priority (per Get-PVal / NeoConfigurationRoot pattern):
    1. Explicit parameter value
    2. Environment variable named like the parameter  ($env:ProGetHost, etc.)
    3. $global:settings entry at the IAC key ('ProGetAdminUriHost', etc.)
    4. Built-in default ('localhost' / 'http' / 50000)

  This script requires elevation (#Requires -RunAsAdministrator) and is
  intentionally located in _AdminRequiresHoldingPen until a dedicated
  administrator-focused module boundary is defined.

.PARAMETER ModuleNames
  Array of PowerShell module names to install. Defaults to the two canonical
  ATAP modules: 'ATAP.Utilities.PowerShell' and
  'ATAP.Utilities.BuildTooling.PowerShell'.

.PARAMETER ProGetHost
  Hostname (or IP address) of the ProGet server.  Resolution order:
  explicit parameter → $env:ProGetHost → $global:settings ProGetAdminUriHost
  → 'localhost'.

.PARAMETER ProGetScheme
  URI scheme for the ProGet server. Resolution order: explicit parameter →
  $env:ProGetScheme → $global:settings ProGetAdminUriScheme → 'http'.

.PARAMETER ProGetPort
  TCP port for the ProGet server. Resolution order: explicit parameter →
  $env:ProGetPort → $global:settings ProGetAdminUriPort → 50000.

.PARAMETER FeedName
  ProGet feed name. Defaults to 'powershellget-stable'.

.OUTPUTS
  PSCustomObject[] — one object per module with properties:
    ModuleName       [string]
    VersionInstalled [string]  (empty string if not installed)
    InstallResult    [string]  'Installed' | 'AlreadyInstalled' | 'NotFound' | 'Skipped'

.EXAMPLE
  # Install from localhost ProGet using all defaults
  Install-ATAPModulesFromProGet

.EXAMPLE
  # Install from a named ProGet server, specific modules only
  Install-ATAPModulesFromProGet `
      -ProGetHost 'proget.corp.local' `
      -ModuleNames @('ATAP.Utilities.PowerShell')

.EXAMPLE
  # Dry run — shows what would be done without making changes
  Install-ATAPModulesFromProGet -WhatIf

.NOTES
  AI assisted using Powershell.instructions.md as guidelines
  Requires elevation: #Requires -RunAsAdministrator
  See also: Register-ProGetFeedSet (for PSResourceRepository registration)

.LINK
  https://github.com/whertzing/ATAP.Utilities
#>
function Install-ATAPModulesFromProGet {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]]$ModuleNames = @(
      'ATAP.Utilities.PowerShell'
      'ATAP.Utilities.BuildTooling.PowerShell'
    ),

    [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$ProGetHost,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$ProGetScheme,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [int]$ProGetPort,

    [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$FeedName = 'powershellget-stable'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'

    # ── Load helper functions ─────────────────────────────────────────────
    # None of this is needed once the modules are built and installed into the
    # PSModulePath, but while we are still running from source code, we need to
    # dot-source the helper functions.  Once the modules are built and installed,
    # all of the helper functions will be available as cmdlets and this block
    # can be removed.
    $helpfunctionsneeded = @(
      # Get-PVal is an alias for Get-ParameterValueFromNeoConfigurationRoot
      @{ FunctionName = 'Get-ParameterValueFromNeoConfigurationRoot'; ModuleName = 'ATAP.Utilities.PowerShell' }
      @{ FunctionName = 'Get-RepositoryRoot'; ModuleName = 'ATAP.Utilities.BuildTooling.PowerShell' }
    )
    $repoRootParentPath = 'C:\Dropbox\whertzing\GitHub'
    $stablePath = 'ATAP.Utilities'
    $wtFolder = $PWD.Path.Split([IO.Path]::DirectorySeparatorChar) |
      Where-Object { $_ -like '*-wt-*' } |
      Select-Object -First 1
    $resolvedModulePath = $wtFolder ?
    $(Join-Path $repoRootParentPath $wtFolder 'src') :
    $(Join-Path $repoRootParentPath $stablePath 'src')
    foreach ($helpfunction in $helpfunctionsneeded) {
      try {
        if (-not (Test-Path -LiteralPath "Function:\$($helpfunction.FunctionName)")) {
          . (Join-Path $resolvedModulePath $helpfunction.ModuleName 'public' "$($helpfunction.FunctionName).ps1")
        }
      } catch {
        $errorMessage = "Failed to load $($helpfunction.FunctionName) from $(Join-Path $resolvedModulePath $helpfunction.ModuleName 'public' "$($helpfunction.FunctionName).ps1"). Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    }
    # End of helper-loading block

    # ── Snippet: Check and populate simple parameter — ProGetHost ─────────
    # Priority: explicit parameter → $env:ProGetHost → settings ProGetAdminUriHost → 'localhost'
    $ProGetHost = Get-PVal `
      -ParameterName 'ProGetHost' `
      -originalPSBoundParameters $PSBoundParameters `
      -dottedPath ($global:configRootKeys['ProGetAdminUriHostConfigRootKey'] ?? 'ProGetAdminUriHost') `
      -DefaultValue 'utat022' `
      -AllowMissing
    # 'utat022', not 'localhost': the ProGet certificate SAN covers only utat022, so a
    # localhost fallback fails TLS validation against the HTTPS-only server.
    if ([string]::IsNullOrWhiteSpace($ProGetHost)) { $ProGetHost = 'utat022' }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ProGetHost resolved to '$ProGetHost'"

    # ── Snippet: Check and populate simple parameter — ProGetScheme ───────
    $ProGetScheme = Get-PVal `
      -ParameterName 'ProGetScheme' `
      -originalPSBoundParameters $PSBoundParameters `
      -dottedPath ($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'] ?? 'ProGetAdminUriScheme') `
      -DefaultValue 'https' `
      -AllowMissing
    # ProGet refuses plain HTTP since the PKI change; a cleartext fallback fails outright.
    if ([string]::IsNullOrWhiteSpace($ProGetScheme)) { $ProGetScheme = 'https' }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ProGetScheme resolved to '$ProGetScheme'"

    # ── Snippet: Check and populate simple parameter as Type — ProGetPort ─
    $resolvedPort = Get-PVal `
      -ParameterName 'ProGetPort' `
      -originalPSBoundParameters $PSBoundParameters `
      -dottedPath ($global:configRootKeys['ProGetAdminUriPortConfigRootKey'] ?? 'ProGetAdminUriPort') `
      -DefaultValue 50000 `
      -AsType ([int]) `
      -AllowMissing
    $ProGetPort = if ($resolvedPort -gt 0) { [int]$resolvedPort } else { 50000 }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ProGetPort resolved to $ProGetPort"

    # ── Compose the feed URI using [UriBuilder] ───────────────────────────
    # Matches the pattern in HostSettings.IAC.Fragment.PackageRepositories.ProGetFeeds.ps1
    $feedPath = "nuget/$FeedName/"
    $sourceUri = ([UriBuilder]::new($ProGetScheme, $ProGetHost, $ProGetPort, $feedPath, '')).Uri.ToString()
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Feed URI: $sourceUri"

    # ── Verify the feed is reachable ──────────────────────────────────────
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $sourceUri" -Tag 'WebRequestCall'
      $null = Invoke-WebRequest -Uri $sourceUri -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $sourceUri" -Tag 'WebRequestCall'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Feed '$FeedName' is reachable at $sourceUri"
    } catch {
      $errorMessage = "Feed '$FeedName' is NOT reachable at '$sourceUri': $($_.Exception.Message). Ensure the ProGet service is running before proceeding."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # ── Ensure the PSRepository is registered and trusted ─────────────────
    $existingRepo = Get-PSRepository -Name $FeedName -ErrorAction SilentlyContinue
    if ($null -eq $existingRepo) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Registering PSRepository '$FeedName'"
      if ($PSCmdlet.ShouldProcess("PSRepository '$FeedName' at $sourceUri", 'Register-PSRepository')) {
        try {
          Register-PSRepository `
            -Name $FeedName `
            -SourceLocation $sourceUri `
            -PublishLocation $sourceUri `
            -InstallationPolicy Trusted
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Registered and trusted PSRepository '$FeedName'"
        } catch {
          $errorMessage = "Failed to register PSRepository '$FeedName'. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw
        }
      }
    } elseif ($existingRepo.InstallationPolicy -ne 'Trusted') {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Setting PSRepository '$FeedName' to Trusted"
      if ($PSCmdlet.ShouldProcess("PSRepository '$FeedName'", 'Set-PSRepository -InstallationPolicy Trusted')) {
        Set-PSRepository -Name $FeedName -InstallationPolicy Trusted
      }
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "PSRepository '$FeedName' is already registered and Trusted"
    }

    # ── Verify ProGet repository order vs PSGallery ───────────────────────
    $allRepos = Get-PSRepository
    $proGetIndex = [array]::IndexOf([string[]]($allRepos.Name), $FeedName)
    $galleryIndex = [array]::IndexOf([string[]]($allRepos.Name), 'PSGallery')
    if ($proGetIndex -ge 0 -and $galleryIndex -ge 0 -and $proGetIndex -gt $galleryIndex) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message `
        "'$FeedName' (index $proGetIndex) is registered AFTER PSGallery (index $galleryIndex). Find-Module will be called with -Repository '$FeedName' explicitly to guarantee the internal feed is used."
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Repository ordering OK: '$FeedName' appears before PSGallery (or PSGallery is absent)"
    }
  }

  process { }

  end {
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($moduleName in $ModuleNames) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Processing module '$moduleName'"

      # ── Check if already installed ──────────────────────────────────────
      $existing = Get-Module -Name $moduleName -ListAvailable |
        Sort-Object Version -Descending |
        Select-Object -First 1
      if ($existing) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Module '$moduleName' version $($existing.Version) is already installed at '$($existing.ModuleBase)'"
        $results.Add([PSCustomObject]@{
            ModuleName       = $moduleName
            VersionInstalled = $existing.Version.ToString()
            InstallResult    = 'AlreadyInstalled'
          })
        continue
      }

      # ── Confirm the module exists on the feed ───────────────────────────
      $found = $null
      try {
        $found = Find-Module -Name $moduleName -Repository $FeedName -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found '$moduleName' version $($found.Version) on '$FeedName'"
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Module '$moduleName' was NOT found on feed '$FeedName' — skipping. Exception: $($_.Exception.Message)"
        $results.Add([PSCustomObject]@{
            ModuleName       = $moduleName
            VersionInstalled = ''
            InstallResult    = 'NotFound'
          })
        continue
      }

      # ── Install globally ────────────────────────────────────────────────
      if ($PSCmdlet.ShouldProcess("'$moduleName' v$($found.Version) from '$FeedName'", 'Install-Module -Scope AllUsers')) {
        try {
          Install-Module `
            -Name $moduleName `
            -Repository $FeedName `
            -Scope AllUsers `
            -Force `
            -AllowClobber `
            -ErrorAction Stop

          $installed = Get-Module -Name $moduleName -ListAvailable |
            Sort-Object Version -Descending |
            Select-Object -First 1
          $installedVersion = if ($installed) { $installed.Version.ToString() } else { $found.Version.ToString() }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Installed '$moduleName' v$installedVersion to '$($installed.ModuleBase)'"
          $results.Add([PSCustomObject]@{
              ModuleName       = $moduleName
              VersionInstalled = $installedVersion
              InstallResult    = 'Installed'
            })
        } catch {
          $errorMessage = "Failed to install module '$moduleName'. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $results.Add([PSCustomObject]@{
              ModuleName       = $moduleName
              VersionInstalled = ''
              InstallResult    = 'Skipped'
            })
        }
      } else {
        # -WhatIf path
        $results.Add([PSCustomObject]@{
            ModuleName       = $moduleName
            VersionInstalled = ''
            InstallResult    = 'Skipped'
          })
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
    $results
  }
}
