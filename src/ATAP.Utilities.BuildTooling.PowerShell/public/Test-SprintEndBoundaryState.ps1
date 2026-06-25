function Test-SprintEndBoundaryState {
  <#
  .SYNOPSIS
  Audits machine, user, profile, workspace, and adapter state at SprintEnd.

  .DESCRIPTION
  Finds stale sprint-worktree references, missing profile files, prohibited
  secret/API-key environment variables, and fresh-shell profile failures. The
  function is read-only and accepts additional profile paths for service
  accounts whose homes are available to the caller.

  .PARAMETER GitRoot
  Parent directory containing repositories and workspace files.

  .PARAMETER SearchRoots
  Filesystem roots to inspect for stale sprint paths.

  .PARAMETER ProfilePaths
  Machine, user, and service-account PowerShell profile paths to verify.

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

    $profileResults = foreach ($profilePath in @($ProfilePaths | Where-Object { $_ } | Select-Object -Unique)) {
      [PSCustomObject]@{
        Path   = $profilePath
        Exists = (Test-Path -LiteralPath $profilePath -PathType Leaf)
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
    $failures = [System.Collections.Generic.List[string]]::new()
    if ($staleReferences.Count -gt 0) { [void]$failures.Add('StaleSprintReferences') }
    if ($environmentFindings.Count -gt 0) { [void]$failures.Add('SecretEnvironmentVariables') }
    if (-not $freshShell.Ok) { [void]$failures.Add('FreshShellProfile') }
    $result = [PSCustomObject]@{
      Ok                           = ($failures.Count -eq 0)
      StaleReferences              = $staleReferences.ToArray()
      Profiles                     = @($profileResults)
      MissingProfiles              = $missingProfiles
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
