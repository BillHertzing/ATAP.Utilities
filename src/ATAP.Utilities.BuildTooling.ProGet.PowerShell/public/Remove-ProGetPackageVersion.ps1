#Requires -Version 7.0
function Remove-ProGetPackageVersion {
  <#
  .SYNOPSIS
  Removes one exact package version from one ProGet feed.

  .DESCRIPTION
  Performs a bounded HTTP POST for the exact feed, package ID, and package
  version supplied by the caller. The command is intentionally limited to
  package-version deletion: it does not publish, promote, rename, or delete a
  feed. HTTP 404 is treated as an idempotent already-absent result.

  The ProGet API key is resolved only after ShouldProcess approves the exact
  destructive operation. When ProGetApiKeySecretName is not explicitly bound,
  its host suffix is derived from the configured ProGet service placement.

  A successful package-deletion response is not independent proof that the package is no
  longer visible through the feed. Callers performing a retirement workflow
  must verify absence separately through the appropriate package query endpoint.
  Before invoking this command, callers must stop unless a current live-version
  preflight exactly matches the separately authorized target set.

  .PARAMETER FeedName
  The exact ProGet feed containing the package version.

  .PARAMETER PackageId
  The exact package ID to remove.

  .PARAMETER PackageVersion
  The exact package version to remove.

  .PARAMETER ProGetBaseUrl
  The ProGet service base URL. When omitted, the command uses
  $global:ProGetBaseUrl or the ProGetBaseUrl build-tooling setting.

  .PARAMETER ProGetApiKeySecretName
  The Bitwarden Secrets Manager SecretName for the ProGet administration key.
  When omitted, the canonical ProGet.Admin.API.Key base is host-suffixed from
  the configured ProGet service placement.

  .OUTPUTS
  PSCustomObject containing only the exact target and redacted outcome state.

  .EXAMPLE
  Remove-ProGetPackageVersion -FeedName 'database-experimental' `
    -PackageId 'ATAPUtilities.Database' -PackageVersion '0.1.3' `
    -ProGetBaseUrl 'https://proget.example.invalid' -WhatIf

  Shows the exact destructive target without resolving a credential or calling
  ProGet.

  .NOTES
  Requires ProGet 2023 or later. This command uses the official Package API HTTP
  Request Specification: POST
  /api/packages/{feed-name}/delete?name={package}&version={version}.

  The command deliberately cannot decide whether the surrounding feed inventory
  still matches a human-approved retirement matrix. A current live-version
  preflight is therefore a caller-side stop condition, and a post-delete live
  query remains required before absence may be claimed.

  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$FeedName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageVersion,

    [Parameter()]
    [string]$ProGetBaseUrl,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProGetApiKeySecretName = 'ProGet.Admin.API.Key'
  )

  begin {
    $fn = 'Remove-ProGetPackageVersion'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if ([string]::IsNullOrWhiteSpace($FeedName) -or
      [string]::IsNullOrWhiteSpace($PackageId) -or
      [string]::IsNullOrWhiteSpace($PackageVersion)) {
      throw 'FeedName, PackageId, and PackageVersion must contain non-whitespace values.'
    }

    if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
      $globalBaseUrl = Get-Variable -Name ProGetBaseUrl -Scope Global -ErrorAction SilentlyContinue
      if ($null -ne $globalBaseUrl) {
        $ProGetBaseUrl = [string]$globalBaseUrl.Value
      }
    }
    if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl) -and
      (Get-Command -Name 'Resolve-BuildToolingSettingValue' -ErrorAction SilentlyContinue)) {
      $ProGetBaseUrl = [string](Resolve-BuildToolingSettingValue -Name 'ProGetBaseUrl' -ErrorAction Stop)
    }
    if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
      throw 'ProGetBaseUrl could not be resolved. Pass it explicitly or load the ATAP ProGet settings.'
    }

    $baseUrl = $ProGetBaseUrl.TrimEnd('/')
    $escapedFeedName = [uri]::EscapeDataString($FeedName)
    $escapedPackageId = [uri]::EscapeDataString($PackageId)
    $escapedPackageVersion = [uri]::EscapeDataString($PackageVersion)
    $deleteUri = "$baseUrl/api/packages/$escapedFeedName/delete?name=$escapedPackageId&version=$escapedPackageVersion"
  }

  process {
    $target = "feed '$FeedName', package '$PackageId', version '$PackageVersion'"
    $action = 'Permanently delete exact ProGet package version'
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
      return [PSCustomObject]@{
        FeedName             = $FeedName
        PackageId            = $PackageId
        PackageVersion       = $PackageVersion
        PreflightState       = 'NotPerformed'
        DeletionAttempted    = $false
        Deleted              = $false
        AlreadyAbsent        = $false
        PostVerificationState = 'NotPerformed'
      }
    }

    if (-not $PSBoundParameters.ContainsKey('ProGetApiKeySecretName')) {
      if (-not (Get-Command -Name 'Resolve-HostSuffixedSecretName' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.Common.PowerShell' 'public' 'Resolve-HostSuffixedSecretName.ps1')
      }
      $ProGetApiKeySecretName = Resolve-HostSuffixedSecretName `
        -BaseName $ProGetApiKeySecretName `
        -ServiceName 'ProGet' `
        -SettingName 'ProGetAdminApiKeySecretName'
    }

    $apiKey = $null
    $headers = $null
    try {
      try {
        $apiKey = [string](Get-SecretATAP `
          -SecretName $ProGetApiKeySecretName `
          -SecretStoreType 'BitwardenSecretsManager' `
          -ErrorAction Stop)
      } catch {
        throw "Unable to resolve the ProGet administration credential from SecretName '$ProGetApiKeySecretName'."
      }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "The ProGet administration credential SecretName '$ProGetApiKeySecretName' resolved to an empty value."
      }

      $headers = @{
        Accept     = 'application/json'
        'X-ApiKey' = $apiKey
      }

      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $deleteUri" -Tag 'RestCall'
        $null = Invoke-RestMethod `
          -Uri $deleteUri `
          -Method Post `
          -Headers $headers `
          -ConnectionTimeoutSeconds 30 `
          -OperationTimeoutSeconds 30 `
          -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $deleteUri" -Tag 'RestCall'

        return [PSCustomObject]@{
          FeedName             = $FeedName
          PackageId            = $PackageId
          PackageVersion       = $PackageVersion
          PreflightState       = 'NotPerformed'
          DeletionAttempted    = $true
          Deleted              = $true
          AlreadyAbsent        = $false
          PostVerificationState = 'RequiresIndependentVerification'
        }
      } catch {
        $statusCode = $null
        if ($null -ne $_.Exception.Response -and $null -ne $_.Exception.Response.StatusCode) {
          $statusCode = [int]$_.Exception.Response.StatusCode
        } elseif ($null -ne $_.Exception.StatusCode) {
          $statusCode = [int]$_.Exception.StatusCode
        }

        if ($statusCode -eq 404) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "The exact package version is already absent from feed '$FeedName'."
          return [PSCustomObject]@{
            FeedName             = $FeedName
            PackageId            = $PackageId
            PackageVersion       = $PackageVersion
            PreflightState       = 'NotPerformed'
            DeletionAttempted    = $true
            Deleted              = $false
            AlreadyAbsent        = $true
            PostVerificationState = 'AbsentByDeleteResponse'
          }
        }

        if ($statusCode -in @(401, 403)) {
          $errorMessage = "ProGet rejected authorization for exact package-version deletion (HTTP $statusCode)."
        } elseif ($null -ne $statusCode) {
          $errorMessage = "ProGet exact package-version deletion failed (HTTP $statusCode)."
        } else {
          $errorMessage = 'ProGet exact package-version deletion failed before a classified HTTP response was received.'
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }
    } finally {
      if ($null -ne $headers) {
        $headers.Clear()
      }
      $headers = $null
      $apiKey = $null
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
