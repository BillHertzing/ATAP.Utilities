function Resolve-BWSReadOnlyBootstrapIdentity {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AccountName
  )

  begin {
    # Policy table, not a seam. Project and application are properties OF an approved identity,
    # never caller input, so there is deliberately no -ProjectName or -ApplicationId parameter.
    # An identity with a null ApplicationId writes the legacy common-CI CLIXML slot; an identity
    # carrying an ApplicationId writes the AtapBwsDpapiEnvelope application slot instead.
    $approvedAccounts = @{
      'svcbuildmaster' = @{ SamAccountName = 'SvcBuildMaster'; ProjectName = 'CI-Shared'; ApplicationId = $null }
      'svcproget' = @{ SamAccountName = 'SvcProGet'; ProjectName = 'CI-Shared'; ApplicationId = $null }
      'svcsqlserver' = @{ SamAccountName = 'SvcSQLServer'; ProjectName = 'CI-Shared'; ApplicationId = $null }
      'svcaceoutpost' = @{ SamAccountName = 'SvcAceOutpost'; ProjectName = 'AceOutpost'; ApplicationId = 'AceOutpost' }
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

    $approvedAccount = $approvedAccounts[$samAccountName.ToLowerInvariant()]
    if ($null -eq $approvedAccount) {
      throw "BWS ReadOnly bootstrap identity '$AccountName' is not approved."
    }
    $approvedSamAccountName = $approvedAccount.SamAccountName

    [PSCustomObject]@{
      AccountName    = "$env:COMPUTERNAME\$approvedSamAccountName"
      SamAccountName = $approvedSamAccountName
      ProjectName    = $approvedAccount.ProjectName
      ApplicationId  = $approvedAccount.ApplicationId
      TokenPurpose   = 'ReadOnly'
    }
  }

  end {
  }
}

function Get-BWSReadOnlyBootstrapTokenFileName {
  <#
    Single source of truth for the token filename of a resolved bootstrap identity, shared by
    Invoke-BWSReadOnlyTokenBootstrap and Invoke-BWSReadOnlyBootstrapWorker. It lives beside the
    resolver because both callers already dot-source this file, and because a duplicated format
    string is exactly how the orchestrator and the worker would drift into probing one path while
    writing another.

    Legacy identities keep the historical casing verbatim ($env:COMPUTERNAME and the proper-case
    SAM name). Application identities use the casing the .NET reader derives: upper-invariant host
    and lower-invariant SAM name.

    The host comes from $env:COMPUTERNAME here, matching the rest of the bootstrap orchestration,
    whereas Initialize-BWSApplicationAccessToken derives it from [System.Environment]::MachineName
    because that is the identity-binding surface and must not be spoofable by environment
    manipulation. If the two ever disagree the orchestrator probes a path the worker did not
    write, and the bootstrap fails closed rather than reporting a token it cannot find.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [psobject]$Identity
  )

  process {
    if ([string]::IsNullOrWhiteSpace($Identity.ApplicationId)) {
      return '{0}_{1}_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml' -f $env:COMPUTERNAME, $Identity.SamAccountName
    }

    '{0}_{1}_BWS_{2}_ReadOnly_AccessToken.xml' -f
      $env:COMPUTERNAME.ToUpperInvariant(),
      $Identity.SamAccountName.ToLowerInvariant(),
      $Identity.ApplicationId
  }
}
