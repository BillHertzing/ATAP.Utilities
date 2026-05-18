#region Get-TierFromNBGVLabel
<#
.SYNOPSIS
  Translate an NBGV prerelease label (or a full prerelease segment) into the
  corresponding promotion ceiling number, tier name, and target ProGet feed.
.DESCRIPTION
  Accepts the bare label (`Alpha`), the combined label+height form
  (`Alpha6`), or the dotted form (`Alpha.6`). Feature labels and other
  non-reserved prerelease labels are interpreted as an Experimental ceiling.
  An empty string or `$null` is interpreted as a T5 Production build.

  This cmdlet is retained for existing callers. New pipeline code should use
  `Get-BuildContext.CeilingTier` and `Test-PromotionWithinCeiling`.

    | Label  | Tier            | Feed                         |
    |--------|-----------------|------------------------------|
    | Sprint | T1 Experimental | powershellget-experimental   |
    | other  | T1 Experimental | powershellget-experimental   |
    | Alpha  | T2 Development  | powershellget-development    |
    | Beta   | T3 Integration  | powershellget-integration    |
    | QA     | T4 QA           | powershellget-qa             |
    | (none) | T5 Production   | powershellget-stable         |
.PARAMETER PrereleaseLabel
  The label to translate. Reserved labels are `Sprint`, `Alpha`, `Beta`, `QA`,
  or an empty string / `$null` for Production. Case-insensitive. May also be supplied as the
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
           2 Development powershellget-development
.EXAMPLE
  PS> Get-TierFromNBGVLabel -PrereleaseLabel 'Alpha.6'
  # same result — the '.6' height is stripped internally
.EXAMPLE
  PS> Get-TierFromNBGVLabel -PrereleaseLabel ''
  TierNumber TierName   FeedName
  ---------- --------   --------
           5 Production powershellget-stable
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
    # Normalize: empty / null -> production
    $labelWasEmpty = $null -eq $PrereleaseLabel -or [string]::IsNullOrWhiteSpace($PrereleaseLabel)
    if ($labelWasEmpty) {
      $normalized = ''
    } else {
      # Accept 'Alpha', 'Alpha6', 'Alpha.6' — strip leading '-' and trailing height
      $trimmed = $PrereleaseLabel.Trim().TrimStart('-')
      # Remove dotted height: 'Alpha.6' -> 'Alpha'
      $trimmed = ($trimmed -split '\.')[0]
      # Remove trailing digits: 'Alpha6' -> 'Alpha'
      $normalized = ($trimmed -replace '\d+$', '')
      if ([string]::IsNullOrWhiteSpace($normalized)) {
        $normalized = '__unknown__'
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Normalized label to '$normalized'" -Tag 'Tier'

    # Case-insensitive lookup
    $key = $normalized.ToLowerInvariant()

    switch ($key) {
      'sprint' {
        $result = [PSCustomObject]@{
          TierNumber = 1
          TierName   = 'Experimental'
          FeedName   = 'powershellget-experimental'
        }
        break
      }
      'alpha' {
        $result = [PSCustomObject]@{
          TierNumber = 2
          TierName   = 'Development'
          FeedName   = 'powershellget-development'
        }
        break
      }
      'beta' {
        $result = [PSCustomObject]@{
          TierNumber = 3
          TierName   = 'Integration'
          FeedName   = 'powershellget-integration'
        }
        break
      }
      'qa' {
        $result = [PSCustomObject]@{
          TierNumber = 4
          TierName   = 'QA'
          FeedName   = 'powershellget-qa'
        }
        break
      }
      '' {
        $result = [PSCustomObject]@{
          TierNumber = 5
          TierName   = 'Production'
          FeedName   = 'powershellget-stable'
        }
        break
      }
      default {
        $result = [PSCustomObject]@{
          TierNumber = 1
          TierName   = 'Experimental'
          FeedName   = 'powershellget-experimental'
        }
        break
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
