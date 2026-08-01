function Resolve-BWSReadOnlyBootstrapIdentity {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AccountName
  )

  begin {
    $approvedAccounts = @{
      'svcbuildmaster' = 'SvcBuildMaster'
      'svcproget' = 'SvcProGet'
      'svcsqlserver' = 'SvcSQLServer'
    }
  }

  process {
    $trimmedAccountName = $AccountName.Trim()
    $accountParts = @($trimmedAccountName -split '\\')
    if ($accountParts.Count -gt 2) {
      throw "BWS ReadOnly bootstrap identity '$AccountName' is not a local account name."
    }

    $samAccountName = $accountParts[-1]
    $qualifier = if ($accountParts.Count -eq 2) { $accountParts[0] } else { '' }
    if (-not [string]::IsNullOrWhiteSpace($qualifier) -and
      $qualifier -ne '.' -and
      $qualifier -ne $env:COMPUTERNAME) {
      throw "BWS ReadOnly bootstrap identity '$AccountName' is not local to '$env:COMPUTERNAME'."
    }

    $approvedSamAccountName = $approvedAccounts[$samAccountName.ToLowerInvariant()]
    if ([string]::IsNullOrWhiteSpace($approvedSamAccountName)) {
      throw "BWS ReadOnly bootstrap identity '$AccountName' is not approved."
    }

    [PSCustomObject]@{
      AccountName    = "$env:COMPUTERNAME\$approvedSamAccountName"
      SamAccountName = $approvedSamAccountName
      ProjectName    = 'CI-Shared'
      TokenPurpose   = 'ReadOnly'
    }
  }

  end {
  }
}
