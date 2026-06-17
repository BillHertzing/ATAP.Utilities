#Requires -Version 7.0

function Test-SprintModulePromotionDeploy {
  <#
  .SYNOPSIS
      Private helper: for a single sprint-built module, asserts its Production
      version is in the *-stable PowerShellGet feed AND installed on this
      workstation.

  .DESCRIPTION
      The Task 9.7 SprintEnd->SprintStart handoff gate. When a sprint builds a
      new module/library version, the next sprint must be able to resolve the
      latest Production module from ProGet and from the local module path. This
      helper performs both halves for one declared module:

        (a) Feed presence — queries the resolved *-stable feed (default
            'powershellget-stable') for the exact version via Find-Module. A
            registered PSRepository of the feed name is preferred; the feed
            endpoint is resolved from $global:Settings when available.
        (b) Workstation install — Get-Module -ListAvailable must report the
            exact version.

      Returns a [PSCustomObject] with Ok plus per-half InStableFeed/Installed
      flags and a remediation string when either half fails. Never throws on a
      genuine "not present" result; only inspection failures surface as Detail.

  .NOTES
      AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter()]
    [string]$StableFeedName = 'powershellget-stable'
  )

  begin {
    $fn = 'Test-SprintModulePromotionDeploy'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $result = [PSCustomObject]@{
      Name         = $Name
      Version      = $Version
      StableFeed   = $StableFeedName
      Ok           = $false
      InStableFeed = $false
      Installed    = $false
      Detail       = ''
      Remediation  = $null
    }

    # ---- (a) Is the exact Production version in the *-stable feed? ----
    $feedDetail = ''
    try {
      # Prefer the feed name/URI from host settings; fall back to the default
      # repository name if settings are not loaded (no-profile / test contexts).
      if (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue) {
        try {
          $feed = Resolve-ProGetFeedFromSettings -FeedType 'powershell' -Tier 'Production'
          if ($null -ne $feed -and -not [string]::IsNullOrWhiteSpace([string]$feed.FeedName)) {
            $StableFeedName = [string]$feed.FeedName
            $result.StableFeed = $StableFeedName
          }
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolve-ProGetFeedFromSettings unavailable for '$Name'; using default feed '$StableFeedName'. Exception: $($_.Exception.Message)"
        }
      }

      $found = Find-Module -Name $Name -RequiredVersion $Version -Repository $StableFeedName -ErrorAction Stop
      if ($null -ne $found) {
        $result.InStableFeed = $true
        $feedDetail = "version $Version present in feed '$StableFeedName'"
      } else {
        $feedDetail = "version $Version NOT found in feed '$StableFeedName'"
      }
    } catch {
      $feedDetail = "version $Version not resolvable in feed '$StableFeedName' ($($_.Exception.Message))"
    }

    # ---- (b) Is the exact version installed on this workstation? ----
    $installDetail = ''
    try {
      $installed = Get-Module -Name $Name -ListAvailable -ErrorAction SilentlyContinue |
        Where-Object { $_.Version.ToString() -eq $Version }
      if ($installed) {
        $result.Installed = $true
        $installDetail = "version $Version installed on workstation"
      } else {
        $available = Get-Module -Name $Name -ListAvailable -ErrorAction SilentlyContinue |
          Sort-Object Version -Descending | Select-Object -First 1
        $installDetail = if ($available) {
          "version $Version NOT installed (highest local is $($available.Version))"
        } else {
          "module '$Name' not installed on workstation"
        }
      }
    } catch {
      $installDetail = "install inspection failed: $($_.Exception.Message)"
    }

    $result.Ok = ($result.InStableFeed -and $result.Installed)
    $result.Detail = "$feedDetail; $installDetail"
    if (-not $result.Ok) {
      $steps = [System.Collections.Generic.List[string]]::new()
      if (-not $result.InStableFeed) {
        [void]$steps.Add("promote $Name $Version to Production (powershellget-stable) via the 5-tier BuildMaster ladder")
      }
      if (-not $result.Installed) {
        [void]$steps.Add("Install-Module -Name $Name -RequiredVersion $Version -Repository $StableFeedName -Scope AllUsers")
      }
      $result.Remediation = $steps -join '; then '
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
