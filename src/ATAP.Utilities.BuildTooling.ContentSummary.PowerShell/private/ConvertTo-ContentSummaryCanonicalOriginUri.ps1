function ConvertTo-ContentSummaryCanonicalOriginUri {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $OriginUri
  )

  begin {
    $fn = 'ConvertTo-ContentSummaryCanonicalOriginUri'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    if ($OriginUri -cne $OriginUri.Trim()) {
      throw 'CS-INVENTORY-001: originUri cannot contain leading or trailing whitespace.'
    }
    $value = $OriginUri
    while ($value.Length -gt 8 -and $value.EndsWith('/')) {
      $value = $value.Substring(0, $value.Length - 1)
    }
    if ($value -notmatch '^(?i:https)://') {
      throw 'CS-INVENTORY-001: originUri must use HTTPS.'
    }
    foreach ($character in $value.ToCharArray()) {
      if ([int]$character -le 31 -or [int]$character -eq 127 -or [char]::IsWhiteSpace($character)) {
        throw 'CS-INVENTORY-001: originUri contains an unsafe character.'
      }
    }
    if ($value.Contains('?') -or $value.Contains('#') -or $value.Contains('\')) {
      throw 'CS-INVENTORY-001: originUri cannot contain query, fragment, or backslash data.'
    }
    $remainder = $value.Substring($value.IndexOf('://') + 3)
    $slashIndex = $remainder.IndexOf('/')
    if ($slashIndex -lt 1 -or $slashIndex -eq $remainder.Length - 1) {
      throw 'CS-INVENTORY-001: originUri requires an authority and repository path.'
    }
    $authority = $remainder.Substring(0, $slashIndex)
    $path = $remainder.Substring($slashIndex + 1)
    if ($authority.Contains('@')) {
      throw 'CS-INVENTORY-001: originUri cannot contain credentials.'
    }
    if ($authority.EndsWith(':443', [StringComparison]::Ordinal)) {
      $authority = $authority.Substring(0, $authority.Length - 4)
    } elseif ($authority.Contains(':')) {
      throw 'CS-INVENTORY-001: originUri cannot contain a non-default port.'
    }
    if ([string]::IsNullOrWhiteSpace($authority) -or $authority.StartsWith('.') -or
      $authority.EndsWith('.') -or $authority.Contains('..') -or $path.Contains('//') -or
      ("/$path/").Contains('/./') -or ("/$path/").Contains('/../')) {
      throw 'CS-INVENTORY-001: originUri authority or repository path is unsafe.'
    }
    return "https://$($authority.ToLowerInvariant())/$path"
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
