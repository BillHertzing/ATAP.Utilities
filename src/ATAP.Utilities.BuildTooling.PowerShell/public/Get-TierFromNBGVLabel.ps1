#region Get-TierFromNBGVLabel
<#
.SYNOPSIS
  Translate an NBGV prerelease label (or a full prerelease segment) into the
  corresponding 5-Tier tier number, tier name, and target ProGet feed.
.DESCRIPTION
  Accepts the bare label (`Alpha`), the combined label+height form
  (`Alpha6`), or the dotted form (`Alpha.6`). An empty string or `$null`
  is interpreted as a stable / T5 Production build.

  The mapping is authoritative per
  `src/ATAP.Utilities.BuildTooling.PowerShell/Documentation/5tier Implementation plan.md`
  sections 3.2 and 4.1:

    | Label  | Tier            | Feed                         |
    |--------|-----------------|------------------------------|
    | Sprint | T1 Experimental | PowershellGet-experimental   |
    | Alpha  | T2 Development  | PowershellGet-development    |
    | Beta   | T3 Integration  | PowershellGet-integration    |
    | QA     | T4 QA           | PowershellGet-qa             |
    | (none) | T5 Production   | PowershellGet-stable         |

  Any other value produces a clear terminating error.
.PARAMETER PrereleaseLabel
  The label to translate. One of `Sprint`, `Alpha`, `Beta`, `QA`, or an empty
  string / `$null` for stable. Case-insensitive. May also be supplied as the
  full prerelease segment (e.g. `Alpha6`, `Alpha.6`) — the trailing numeric
  height is stripped before lookup.
.INPUTS
  None. This cmdlet does not accept pipeline input.
.OUTPUTS
  [PSCustomObject] with `TierNumber`, `TierName`, and `FeedName`.
.EXAMPLE
  PS> Get-TierFromNBGVLabel -PrereleaseLabel 'Alpha'
  TierNumber TierName    FeedName
  ---------- --------    --------
           2 Development PowershellGet-development
.EXAMPLE
  PS> Get-TierFromNBGVLabel -PrereleaseLabel 'Alpha.6'
  # same result — the '.6' height is stripped internally
.EXAMPLE
  PS> Get-TierFromNBGVLabel -PrereleaseLabel ''
  TierNumber TierName   FeedName
  ---------- --------   --------
           5 Production PowershellGet-stable
.NOTES
  AI assisted using Powershell.instructions.md as guidelines
.LINK
  https://github.com/dotnet/Nerdbank.GitVersioning
#>
function Get-TierFromNBGVLabel {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param (
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [AllowNull()]
    [string] $PrereleaseLabel
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with PrereleaseLabel='$PrereleaseLabel'" -Tag 'Trace'
  }
  process {
    # Normalize: empty / null -> stable
    if ($null -eq $PrereleaseLabel -or [string]::IsNullOrWhiteSpace($PrereleaseLabel)) {
      $normalized = ''
    } else {
      # Accept 'Alpha', 'Alpha6', 'Alpha.6' — strip leading '-' and trailing height
      $trimmed = $PrereleaseLabel.Trim().TrimStart('-')
      # Remove dotted height: 'Alpha.6' -> 'Alpha'
      $trimmed = ($trimmed -split '\.')[0]
      # Remove trailing digits: 'Alpha6' -> 'Alpha'
      $normalized = ($trimmed -replace '\d+$', '')
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Normalized label to '$normalized'" -Tag 'Tier'

    # Case-insensitive lookup
    $key = $normalized.ToLowerInvariant()

    switch ($key) {
      'sprint' {
        $result = [PSCustomObject]@{
          TierNumber = 1
          TierName   = 'Experimental'
          FeedName   = 'PowershellGet-experimental'
        }
        break
      }
      'alpha' {
        $result = [PSCustomObject]@{
          TierNumber = 2
          TierName   = 'Development'
          FeedName   = 'PowershellGet-development'
        }
        break
      }
      'beta' {
        $result = [PSCustomObject]@{
          TierNumber = 3
          TierName   = 'Integration'
          FeedName   = 'PowershellGet-integration'
        }
        break
      }
      'qa' {
        $result = [PSCustomObject]@{
          TierNumber = 4
          TierName   = 'QA'
          FeedName   = 'PowershellGet-qa'
        }
        break
      }
      '' {
        $result = [PSCustomObject]@{
          TierNumber = 5
          TierName   = 'Production'
          FeedName   = 'PowershellGet-stable'
        }
        break
      }
      default {
        $message = "Unrecognized NBGV prerelease label '$PrereleaseLabel' (normalized to '$normalized'). Expected one of: Sprint, Alpha, Beta, QA, or empty for stable."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'Tier'
        throw $message
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Resolved tier T$($result.TierNumber) $($result.TierName) -> $($result.FeedName)" -Tag 'Tier'
    return $result
  }
  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
#endregion Get-TierFromNBGVLabel
