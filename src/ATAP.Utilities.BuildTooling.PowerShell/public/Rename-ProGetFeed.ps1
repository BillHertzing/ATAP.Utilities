#Requires -Version 7.0
<#
.SYNOPSIS
    Renames a ProGet feed using the ProGet management API.

.DESCRIPTION
    Calls POST /api/management/feeds/update/{oldFeedName} with a JSON body of
    { "name": "newFeedName" } and the X-ApiKey authentication header.

    The ProGet base URL is resolved from (in priority order):
      1. -ProGetBaseUrl parameter
      2. $env:PROGET_BASE_URL (process scope)
      3. User-scope environment variable PROGET_BASE_URL
      4. $global:Settings via $global:configRootKeys (ProGetAdminUriScheme/Host/Port keys)

    The API key is resolved by passing ProGetApiKeySecretName to Get-SecretATAP
    immediately before the authenticated request. Raw API-key parameters and
    environment-variable fallbacks are intentionally unsupported.

    If -WhatIf is supplied, the function returns the planned object without
    contacting the ProGet API.

.PARAMETER OldFeedName
    The current name of the ProGet feed to rename. Required.

.PARAMETER NewFeedName
    The new name to assign to the feed. Required.

.PARAMETER ProGetBaseUrl
    The ProGet server base URL (e.g., 'http://localhost:50000').
    Optional — resolved from $global:settings or environment if omitted.

.PARAMETER ProGetApiKeySecretName
    Name of the Bitwarden secret containing the ProGet administration API key.

.OUTPUTS
    [PSCustomObject] with fields:
      OldFeedName  - The original feed name
      NewFeedName  - The new feed name
      Success      - $true if the API call succeeded, $false on -WhatIf
      Response     - The raw response from ProGet (or $null on -WhatIf)

.EXAMPLE
    Rename-ProGetFeed -OldFeedName 'nuget-sprint' -NewFeedName 'nuget-experimental'

    Renames the feed on the ProGet server configured in $global:settings.

.EXAMPLE
    Rename-ProGetFeed -OldFeedName 'old-feed' -NewFeedName 'new-feed' `
        -ProGetBaseUrl 'http://localhost:50000' -ProGetApiKeySecretName 'ProGet.Admin.API.Key' -WhatIf

    Shows what would happen without contacting ProGet.

.NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
#>
function Rename-ProGetFeed {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [string]$OldFeedName,

    [Parameter(Mandatory)]
    [string]$NewFeedName,

    [string]$ProGetBaseUrl,

    [ValidateNotNullOrEmpty()]
    [string]$ProGetApiKeySecretName = 'ProGet.Admin.API.Key'
  )

  begin {
    $fn = 'Rename-ProGetFeed'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with OldFeedName='$OldFeedName' NewFeedName='$NewFeedName'" -Tag 'Trace'

    # Resolve ProGetBaseUrl: parameter → env var (process) → env var (user) → global settings (scheme+host+port)
    if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
      $ProGetBaseUrl = [Environment]::GetEnvironmentVariable('PROGET_BASE_URL', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
      $ProGetBaseUrl = [Environment]::GetEnvironmentVariable('PROGET_BASE_URL', 'User')
    }
    if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
      if ($null -ne $global:configRootKeys -and $null -ne $global:Settings) {
        $scheme = $global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']]
        $proGetHost = $global:Settings[$global:configRootKeys['ProGetAdminUriHostConfigRootKey']]
        $port = $global:Settings[$global:configRootKeys['ProGetAdminUriPortConfigRootKey']]
        if (-not [string]::IsNullOrWhiteSpace($scheme) -and -not [string]::IsNullOrWhiteSpace($proGetHost)) {
          $ProGetBaseUrl = if ($port) { "${scheme}://${proGetHost}:${port}" } else { "${scheme}://${proGetHost}" }
        }
      }
    }
    if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
      $errorMessage = 'ProGetBaseUrl could not be resolved. Pass -ProGetBaseUrl explicitly, set env var PROGET_BASE_URL, or configure $global:Settings via $global:configRootKeys.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
    $ProGetBaseUrl = $ProGetBaseUrl.TrimEnd('/')
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ProGetBaseUrl resolved to '$ProGetBaseUrl'"

    if (-not $PSBoundParameters.ContainsKey('ProGetApiKeySecretName') -and $global:configRootKeys -and $global:Settings) {
      $settingName = $global:configRootKeys['ProGetAdminApiKeySecretNameConfigRootKey']
      if ($settingName -and $global:Settings[$settingName]) { $ProGetApiKeySecretName = [string]$global:Settings[$settingName] }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "All parameters validated. OldFeedName='$OldFeedName' NewFeedName='$NewFeedName'"
  }

  process {
    $uri = "$ProGetBaseUrl/api/management/feeds/update/$([uri]::EscapeDataString($OldFeedName))"
    $body = @{ name = $NewFeedName } | ConvertTo-Json -Compress
    if (-not $PSCmdlet.ShouldProcess("ProGet feed '$OldFeedName'", "Rename to '$NewFeedName'")) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf active — skipping API call to $uri"
      return [PSCustomObject]@{
        OldFeedName = $OldFeedName
        NewFeedName = $NewFeedName
        Success     = $false
        Response    = $null
      }
    }

    $response = $null
    try {
      if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) { throw 'Get-SecretATAP is required for ProGet authentication.' }
      $adminApiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
      if ([string]::IsNullOrWhiteSpace($adminApiKey)) { throw "Secret '$ProGetApiKeySecretName' did not resolve to a ProGet API key." }
      $headers = @{ 'X-ApiKey' = $adminApiKey; 'Content-Type' = 'application/json' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $uri" -Tag 'RestCall'
      $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $uri" -Tag 'RestCall'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Feed '$OldFeedName' successfully renamed to '$NewFeedName'."
    } catch {
      $errorMessage = "Failed to rename ProGet feed '$OldFeedName' to '$NewFeedName'. Verify ProGet connectivity and the secret named '$ProGetApiKeySecretName'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }

    return [PSCustomObject]@{
      OldFeedName = $OldFeedName
      NewFeedName = $NewFeedName
      Success     = $true
      Response    = $response
    }
  }
}
