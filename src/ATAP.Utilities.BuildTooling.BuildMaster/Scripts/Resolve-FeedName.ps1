<#
.SYNOPSIS
  Resolves a ProGet feed name for a given 5-Tier tier and feed type from
  BuildTooling settings, then writes it to an output file for OtterScript consumption.

.DESCRIPTION
  This script is designed to be invoked from an OtterScript plan via 'Exec pwsh'.
  It translates the OtterScript $Tier variable (Experimental/Development/Integration/
  QA/Production) to the canonical ProGet feed tier, resolves the value via
  Resolve-ProGetFeedFromSettings, and writes the result to -OutputFile so
  OtterScript can read it back with $FileContents().

  If $global:Settings/$global:configRootKeys are not already initialized, the script
  bootstraps the ProGet feed collection from the machine-scope compatibility export
  written by New-HostSettingsForPackageRepositoryFeeds.

  Exit code 0 = success. Any other exit code = failure.

.PARAMETER Tier
  The 5-Tier tier name. One of:
    Experimental, Development, Integration, QA, Production (Stable).

.PARAMETER FeedType
  The feed type. One of: nuget, powershell, powershellget, psresourceget, chocolatey.

.PARAMETER OutputFile
  Relative or absolute path where the resolved feed name is written (no newline).
  Defaults to '_feedname.tmp' in the current directory.

.PARAMETER SettingsPath
  Optional path to the machine-scope HostSettings.PackageRepositoryFeeds.psd1 file.
  Defaults to $env:ProgramData\ATAP\HostSettings.PackageRepositoryFeeds.psd1.

.OUTPUTS
  Writes the resolved feed name string to -OutputFile. No pipeline output.

.EXAMPLE
  # From OtterScript:
  Exec pwsh
  (
      Arguments: >>-File Build/BuildMaster/Scripts/Resolve-FeedName.ps1 -Tier $Tier -FeedType nuget -OutputFile _feedname.tmp>>,
      WorkingDirectory: $SourcePath,
      SuccessExitCode: 0
  );
  set $FeedName = $Trim($FileContents($PathCombine($SourcePath, _feedname.tmp)));

.NOTES
  AI assisted using Powershell.instructions.md as guidelines
  Phase 3C - T-31 (7.1-3 OtterScript feed name resolution from BuildTooling settings)
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production', 'Stable')]
  [string]$Tier,

  [Parameter(Mandatory)]
  [ValidateSet('nuget', 'powershell', 'powershellget', 'psresourceget', 'chocolatey')]
  [string]$FeedType,

  [string]$OutputFile = '_feedname.tmp',

  [string]$SettingsPath = (Join-Path $env:ProgramData 'ATAP\HostSettings.PackageRepositoryFeeds.psd1')
)

$ErrorActionPreference = 'Stop'

function Resolve-FeedName {
  <#
  .SYNOPSIS
    Eponymous worker that resolves the ProGet feed name and writes it to a file.
  .DESCRIPTION
    Receives the same parameters as the script entry-point. Uses
    Resolve-ProGetFeedFromSettings against the BuildTooling settings hashtable,
    bootstrapping that hashtable from the machine-scope export if necessary.
  .OUTPUTS
    [string] The resolved feed name (also written to -OutputFile).
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][string]$Tier,
    [Parameter(Mandatory)][string]$FeedType,
    [Parameter(Mandatory)][string]$OutputFile,
    [Parameter(Mandatory)][string]$SettingsPath
  )

  begin {
    $fn = 'Resolve-FeedName'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn (Tier='$Tier'; FeedType='$FeedType')"

    function Get-RepositoryRootLocal {
      [CmdletBinding()]
      [OutputType([string])]
      param()
      begin { $f = 'Get-RepositoryRootLocal'; $m = 'ATAP.Utilities.BuildTooling.BuildMaster' }
      process {
        $current = $PSScriptRoot
        while (-not [string]::IsNullOrWhiteSpace($current)) {
          if (Test-Path -LiteralPath (Join-Path $current '.git')) {
            return $current
          }
          $parent = Split-Path -Parent $current
          if ($parent -eq $current) { break }
          $current = $parent
        }
        try {
          $gitOutput = & git -c safe.directory='*' rev-parse --show-toplevel 2>$null
          if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitOutput)) {
            return [string]$gitOutput.Trim()
          }
        } catch {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Verbose -Message "git rev-parse failed: $($_.Exception.Message)"
        }
        throw "Resolve-FeedName : Unable to locate repository root from '$PSScriptRoot'."
      }
      end {}
    }

    function Get-BuildToolingFeedResolverPathLocal {
      [CmdletBinding()]
      [OutputType([string])]
      param()
      begin { $f = 'Get-BuildToolingFeedResolverPathLocal'; $m = 'ATAP.Utilities.BuildTooling.BuildMaster' }
      process {
        if (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue) {
          return $null
        }
        $repoRoot = Get-RepositoryRootLocal
        $resolverPath = Join-Path $repoRoot 'src\ATAP.Utilities.BuildTooling.ProGet.PowerShell\public\Resolve-ProGetFeedFromSettings.ps1'
        if (-not (Test-Path -LiteralPath $resolverPath -PathType Leaf)) {
          throw "Resolve-FeedName : Resolve-ProGetFeedFromSettings.ps1 not found at '$resolverPath'."
        }
        return $resolverPath
      }
      end {}
    }

    function Initialize-ProGetFeedSettingsLocal {
      [CmdletBinding()]
      param([Parameter(Mandatory)][string]$SettingsPath)
      begin { $f = 'Initialize-ProGetFeedSettingsLocal'; $m = 'ATAP.Utilities.BuildTooling.BuildMaster' }
      process {
        if ($null -ne $global:Settings -and $null -ne $global:configRootKeys) {
          $feedCollectionKey = $global:configRootKeys['ProGetFeedCollectionConfigRootKey']
          if (-not [string]::IsNullOrWhiteSpace($feedCollectionKey) -and $null -ne $global:Settings[$feedCollectionKey]) {
            return
          }
        }
        if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
          throw "Resolve-FeedName : BuildTooling feed settings are not initialized and '$SettingsPath' was not found. Run New-HostSettingsForPackageRepositoryFeeds or pass -SettingsPath."
        }
        try {
          $feedSettings = Import-PowerShellDataFile -LiteralPath $SettingsPath
        } catch {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Error -Message "Import-PowerShellDataFile failed for '$SettingsPath'. Exception: $($_.Exception.Message)"
          throw
        } finally {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Debug -Message "Import attempt complete for '$SettingsPath'."
        }
        if ($null -eq $feedSettings.Feeds) {
          throw "Resolve-FeedName : '$SettingsPath' does not contain a Feeds hashtable."
        }
        if ($null -eq $global:configRootKeys) { $global:configRootKeys = @{} }
        $global:configRootKeys['ProGetFeedCollectionConfigRootKey'] = 'ProGetFeedCollection'
        if ($null -eq $global:Settings) { $global:Settings = @{} }
        $global:Settings['ProGetFeedCollection'] = $feedSettings.Feeds
      }
      end {}
    }
  }

  process {
    try {
      $resolverPath = Get-BuildToolingFeedResolverPathLocal
      if ($null -ne $resolverPath) {
        . $resolverPath
      }
      Initialize-ProGetFeedSettingsLocal -SettingsPath $SettingsPath

      try {
        $feed = Resolve-ProGetFeedFromSettings -FeedType $FeedType -Tier $Tier
        $feedName = $feed.FeedName
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Resolve-FeedName : Failed to resolve feed for Tier='$Tier' FeedType='$FeedType'. $($_.Exception.Message)"
        Write-Error "Resolve-FeedName : Failed to resolve feed for Tier='$Tier' FeedType='$FeedType'. $($_.Exception.Message)"
        exit 1
      } finally {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Resolve-ProGetFeedFromSettings call complete.'
      }

      if ([string]::IsNullOrWhiteSpace($feedName)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Resolve-FeedName : Resolved feed name for Tier='$Tier' FeedType='$FeedType' is empty."
        Write-Error "Resolve-FeedName : Resolved feed name for Tier='$Tier' FeedType='$FeedType' is empty."
        exit 1
      }

      $resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
        $OutputFile
      } else {
        Join-Path (Get-Location) $OutputFile
      }

      $feedName | Out-File -FilePath $resolvedOutput -Encoding utf8 -NoNewline
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Resolve-FeedName : Resolved Tier='$Tier' FeedType='$FeedType' -> '$feedName' (written to '$resolvedOutput')"
      return $feedName
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed in $fn. Exception: $($_.Exception.Message)"
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Process complete in $fn."
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Finished $fn"
  }
}

Resolve-FeedName -Tier $Tier -FeedType $FeedType -OutputFile $OutputFile -SettingsPath $SettingsPath | Out-Null
exit 0
