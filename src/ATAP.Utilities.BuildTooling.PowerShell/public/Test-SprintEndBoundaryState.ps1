function Test-SprintEndBoundaryState {
  <#
  .SYNOPSIS
  Audits machine, user, profile, workspace, and adapter state at SprintEnd.

  .DESCRIPTION
  Finds stale sprint-worktree references, missing profile files, prohibited
  secret/API-key environment variables, and fresh-shell profile failures. The
  function is read-only and accepts additional profile paths for service
  accounts whose homes are available to the caller. When `-ProfilePaths` is not
  supplied explicitly, the function also discovers the managed developer and
  service-account profiles that Sprint boundary reset owns and verifies that
  each exists, points at or matches the expected stable profile source, and is
  readable by a fresh PowerShell 7 process.

  .PARAMETER GitRoot
  Parent directory containing repositories and workspace files.

  .PARAMETER SearchRoots
  Filesystem roots to inspect for stale sprint paths.

  .PARAMETER ProfilePaths
  Machine, user, and service-account PowerShell profile paths to verify.

  .PARAMETER ATAPUtilitiesRoot
  Optional ATAP.Utilities repository or worktree root used to resolve the
  expected managed profile sources. Defaults to `<GitRoot>\ATAP.Utilities`.

  .PARAMETER ATAPIACRoot
  Optional ATAP.IAC repository or worktree root used to resolve service-account
  metadata. Defaults to `<GitRoot>\ATAP.IAC`.

  .PARAMETER ProhibitedEnvironmentVariableNames
  Secret-bearing environment variable names that must not exist in Process,
  User, or Machine scope.

  .PARAMETER TestFreshShell
  Starts a profile-enabled PowerShell process and fails on profile error text.

  .PARAMETER ThrowOnFailure
  Throws when the boundary audit is not clean.

  .OUTPUTS
  PSCustomObject containing stale references, profile results, and env findings.

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$GitRoot,

    [Parameter()]
    [string[]]$SearchRoots,

    [Parameter()]
    [string[]]$ProfilePaths = @(
      (Join-Path $PSHOME 'profile.ps1'),
      $PROFILE.AllUsersAllHosts,
      $PROFILE.AllUsersCurrentHost,
      $PROFILE.CurrentUserAllHosts,
      $PROFILE.CurrentUserCurrentHost
    ),

    [Parameter()]
    [string]$ATAPUtilitiesRoot,

    [Parameter()]
    [string]$ATAPIACRoot,

    [Parameter()]
    [string[]]$ProhibitedEnvironmentVariableNames = @(
      'BUILDMASTER_ADMIN_API_KEY',
      'BUILDMASTER_GH_WEBHOOK_SECRET',
      'PROGET_ADMIN_API_KEY',
      'BWS_ACCESS_TOKEN',
      'BW_SESSION'
    ),

    [Parameter()]
    [switch]$TestFreshShell,

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Test-SprintEndBoundaryState'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Get-Command -Name 'Set-SprintBoundaryUserProfiles' -CommandType Function -ErrorAction SilentlyContinue)) {
      $helperPath = Join-Path $PSScriptRoot 'Set-SprintBoundaryUserProfiles.ps1'
      if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
        . $helperPath
      }
    }
  }

  process {
    $gitRootFull = [IO.Path]::GetFullPath($GitRoot)
    if (-not $PSBoundParameters.ContainsKey('SearchRoots')) {
      $SearchRoots = @($gitRootFull)
    }
    $staleReferences = [System.Collections.Generic.List[object]]::new()
    $extensions = @('*.code-workspace', '*.json', '*.jsonc', '*.toml')
    foreach ($searchRoot in $SearchRoots) {
      if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) { continue }
      foreach ($extension in $extensions) {
        foreach ($file in @(Get-ChildItem -LiteralPath $searchRoot -Filter $extension -File -Recurse -ErrorAction SilentlyContinue)) {
          if ($file.FullName -match '[\\/](?:\.git|_generated|SprintHistory)[\\/]') { continue }
          $referenceMatches = Select-String -LiteralPath $file.FullName `
            -Pattern '-wt-\d+-Sprint-\d{4}-work-items' -AllMatches -ErrorAction SilentlyContinue
          foreach ($match in $referenceMatches) {
            [void]$staleReferences.Add([PSCustomObject]@{
                Path = $file.FullName
                LineNumber = $match.LineNumber
                Text = $match.Line.Trim()
              })
          }
        }
      }
    }

    if (-not $PSBoundParameters.ContainsKey('ATAPUtilitiesRoot') -or [string]::IsNullOrWhiteSpace($ATAPUtilitiesRoot)) {
      $ATAPUtilitiesRoot = Join-Path $gitRootFull 'ATAP.Utilities'
    }
    if (-not $PSBoundParameters.ContainsKey('ATAPIACRoot') -or [string]::IsNullOrWhiteSpace($ATAPIACRoot)) {
      $ATAPIACRoot = Join-Path $gitRootFull 'ATAP.IAC'
    }

    $managedProfileDefinitions = @()
    if (-not $PSBoundParameters.ContainsKey('ProfilePaths')) {
      try {
        $managedProfileDiscovery = Set-SprintBoundaryUserProfiles `
          -ATAPUtilitiesRoot $ATAPUtilitiesRoot `
          -ATAPIACRoot $ATAPIACRoot `
          -GitRoot $gitRootFull `
          -Confirm:$false `
          -WhatIf
        $managedProfileDefinitions = @($managedProfileDiscovery.Profiles)
      } catch {
        $managedProfileDefinitions = @()
      }
    }

    $allProfilePaths = [System.Collections.Generic.List[string]]::new()
    foreach ($profilePath in @($ProfilePaths | Where-Object { $_ } | Select-Object -Unique)) {
      if (-not $allProfilePaths.Contains($profilePath)) {
        [void]$allProfilePaths.Add($profilePath)
      }
    }
    foreach ($managedProfilePath in @($managedProfileDefinitions.ProfilePath | Where-Object { $_ } | Select-Object -Unique)) {
      if (-not $allProfilePaths.Contains($managedProfilePath)) {
        [void]$allProfilePaths.Add($managedProfilePath)
      }
    }

    $profileResults = foreach ($profilePath in $allProfilePaths) {
      $managedDefinition = @($managedProfileDefinitions | Where-Object { $_.ProfilePath -eq $profilePath } | Select-Object -First 1)
      $exists = Test-Path -LiteralPath $profilePath -PathType Leaf
      $freshShellReadable = $false
      if ($exists) {
        $readResult = Invoke-SprintEndNativeCommand -FilePath 'pwsh' `
          -ArgumentList @('-Command', "& { Get-Content -LiteralPath '$profilePath' -TotalCount 1 | Out-Null; 'PROFILE_READ_OK' }") `
          -AllowNonZeroExitCode
        $freshShellReadable = $readResult.Succeeded -and ($readResult.Output -contains 'PROFILE_READ_OK')
      }

      $profileItem = if ($exists) { Get-Item -LiteralPath $profilePath -Force -ErrorAction SilentlyContinue } else { $null }
      $linkTarget = if ($profileItem -and $profileItem.PSObject.Properties['Target']) {
        @($profileItem.Target) | Select-Object -First 1
      } else {
        $null
      }
      $sourcePath = if ($managedDefinition) { [string]$managedDefinition.SourcePath } else { $null }
      $matchesSource = if ($managedDefinition -and $exists -and (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        if (-not [string]::IsNullOrWhiteSpace($linkTarget)) {
          [string]::Equals(
            [IO.Path]::GetFullPath([string]$linkTarget),
            [IO.Path]::GetFullPath($sourcePath),
            [StringComparison]::OrdinalIgnoreCase
          )
        } else {
          [string]::Equals(
            (Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue),
            (Get-Content -LiteralPath $sourcePath -Raw -ErrorAction SilentlyContinue),
            [StringComparison]::Ordinal
          )
        }
      } else {
        $null
      }
      $containsSprintReference = if ($exists) {
        (Select-String -LiteralPath $profilePath -Pattern '-wt-\d+-Sprint-\d{4}-work-items' -Quiet -ErrorAction SilentlyContinue)
      } else {
        $false
      }

      [PSCustomObject]@{
        Path                 = $profilePath
        Exists               = $exists
        Kind                 = if ($managedDefinition) { $managedDefinition.Kind } else { 'General' }
        Identity             = if ($managedDefinition) { $managedDefinition.Identity } else { $null }
        SourcePath           = $sourcePath
        LinkTarget           = $linkTarget
        MatchesSource        = $matchesSource
        ContainsSprintReference = $containsSprintReference
        FreshShellReadable   = $freshShellReadable
        Skipped              = if ($managedDefinition) { [bool]$managedDefinition.Skipped } else { $false }
        Warning              = if ($managedDefinition) { $managedDefinition.Warning } else { $null }
      }
    }
    $environmentFindings = [System.Collections.Generic.List[object]]::new()
    foreach ($scope in 'Process', 'User', 'Machine') {
      foreach ($name in $ProhibitedEnvironmentVariableNames) {
        $value = [Environment]::GetEnvironmentVariable($name, $scope)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
          [void]$environmentFindings.Add([PSCustomObject]@{
              Name = $name
              Scope = $scope
              Present = $true
            })
        }
      }
    }

    $freshShell = [PSCustomObject]@{ Tested = $false; Ok = $true; ExitCode = 0; Output = @() }
    if ($TestFreshShell) {
      $shellResult = Invoke-SprintEndNativeCommand -FilePath 'pwsh' `
        -ArgumentList @('-Command', "'SPRINT_END_PROFILE_OK'") -AllowNonZeroExitCode
      $errorText = ($shellResult.Output -join [Environment]::NewLine)
      $freshShell = [PSCustomObject]@{
        Tested = $true
        Ok = ($shellResult.Succeeded -and $errorText -notmatch '(?im)ParserError|not recognized|Could not find|The term .* is not recognized')
        ExitCode = $shellResult.ExitCode
        Output = $shellResult.Output
      }
    }

    $missingProfiles = @($profileResults | Where-Object { -not $_.Exists })
    $managedProfileFailures = @(
      $profileResults |
        Where-Object {
          $_.Kind -ne 'General' -and
          -not $_.Skipped -and (
            -not $_.Exists -or
            -not $_.MatchesSource -or
            $_.ContainsSprintReference -or
            -not $_.FreshShellReadable
          )
        }
    )
    $failures = [System.Collections.Generic.List[string]]::new()
    if ($staleReferences.Count -gt 0) { [void]$failures.Add('StaleSprintReferences') }
    if ($environmentFindings.Count -gt 0) { [void]$failures.Add('SecretEnvironmentVariables') }
    if (-not $freshShell.Ok) { [void]$failures.Add('FreshShellProfile') }
    if ($managedProfileFailures.Count -gt 0) { [void]$failures.Add('ManagedUserProfiles') }
    $result = [PSCustomObject]@{
      Ok                           = ($failures.Count -eq 0)
      StaleReferences              = $staleReferences.ToArray()
      Profiles                     = @($profileResults)
      MissingProfiles              = $missingProfiles
      ManagedProfileFailures       = @($managedProfileFailures)
      SecretEnvironmentVariables   = $environmentFindings.ToArray()
      FreshShell                   = $freshShell
      Failures                     = $failures.ToArray()
    }
    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "SprintEnd boundary state failed: $($result.Failures -join ', ')."
    }
    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
