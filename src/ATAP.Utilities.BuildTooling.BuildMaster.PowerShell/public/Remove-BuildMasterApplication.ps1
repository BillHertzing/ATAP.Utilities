function Remove-BuildMasterApplication {
  <#
  .SYNOPSIS
    Removes or deactivates a BuildMaster application through the API.
  .DESCRIPTION
    Removes a BuildMaster application with the Application Management API. By
    default the cmdlet purges the application. Use -DeactivateOnly to retain
    historical data and mark the application inactive instead.

    Missing applications are treated as successful no-ops so the cmdlet is safe
    to re-run.
  .PARAMETER Name
    The BuildMaster application name.
  .PARAMETER DeactivateOnly
    Deactivate the application instead of purging it.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server. Defaults to $global:settings,
    BUILDMASTER_BASE_URL, then http://localhost:50017.
  .PARAMETER BuildMasterAdminApiKeySecretName
    ATAP secret name for the BuildMaster admin API key (Application Management
    permission). Resolved via Get-PVal; value read with Get-SecretATAP.
  .OUTPUTS
    PSCustomObject describing the removal result.
  .EXAMPLE
    Remove-BuildMasterApplication -Name 'Old-App' -Confirm:$false
  .EXAMPLE
    Remove-BuildMasterApplication -Name 'Old-App' -DeactivateOnly
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    https://docs.inedo.com/docs/buildmaster-appmanagement-purge
  .LINK
    https://docs.inedo.com/docs/buildmaster-appmanagement-update
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [switch]$DeactivateOnly,

    [string]$BuildMasterBaseUrl,

    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key'
  )

  begin {
    # SC-0288 / Task 13.66.b: the SecretName host suffix is derived from the service placement
    # host, never hard-coded. Resolution order is the authoritative host setting,
    # then the placement map; an unknown placement host fails closed.
    if (-not $PSBoundParameters.ContainsKey('BuildMasterAdminApiKeySecretName')) {
      if (-not (Get-Command -Name 'Resolve-HostSuffixedSecretName' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.Common.PowerShell' 'public' 'Resolve-HostSuffixedSecretName.ps1')
      }
      $BuildMasterAdminApiKeySecretName = Resolve-HostSuffixedSecretName `
        -BaseName $BuildMasterAdminApiKeySecretName -ServiceName 'BuildMaster' -SettingName 'BuildMasterAdminApiKeySecretName'
    }

    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $BuildMasterAdminApiKeySecretName = Get-PVal -ParameterName 'BuildMasterAdminApiKeySecretName' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterAdminApiKeySecretName

    function Resolve-BuildMasterApiSettings {
      param([string]$BaseUrl, [string]$AdminApiKeySecretName)
      $resolvedBaseUrl = $BaseUrl
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl) -and $null -ne $global:settings) {
        $settingsKey = 'BuildMasterBaseUrl'
        if ($null -ne $global:configRootKeys -and $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']) { $settingsKey = $global:configRootKeys['BuildMasterBaseUrlConfigRootKey'] }
        if ($global:settings.ContainsKey($settingsKey)) { $resolvedBaseUrl = [string]$global:settings[$settingsKey] }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process') }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User') }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = 'http://localhost:50017' }

      # Retrieve the BuildMaster admin API key value via Get-SecretATAP using
      # the resolved secret name. The key value is never logged.
      $resolvedApiKey = $null
      $secretErrors = [System.Collections.Generic.List[string]]::new()
      foreach ($fieldName in @($null, 'token', 'key', 'password')) {
        try {
          $candidate = if ($null -eq $fieldName) {
            Get-SecretATAP -SecretName $AdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
          } else {
            Get-SecretATAP -SecretName $AdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -SecretField $fieldName -ErrorAction Stop
          }
          if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { $resolvedApiKey = [string]$candidate; break }
        } catch {
          $fieldLabel = if ($null -eq $fieldName) { '<default>' } else { $fieldName }
          $secretErrors.Add("${fieldLabel}: $($_.Exception.Message)") | Out-Null
        }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
        $detail = if ($secretErrors.Count -gt 0) { " Last error: $($secretErrors[$secretErrors.Count - 1])" } else { '' }
        throw "Unable to resolve the BuildMaster admin API key value from secret '$AdminApiKeySecretName' via Get-SecretATAP.$detail"
      }
      return [PSCustomObject]@{ BaseUrl = $resolvedBaseUrl.TrimEnd('/'); ApiKey = $resolvedApiKey }
    }

    $settings = Resolve-BuildMasterApiSettings -BaseUrl $BuildMasterBaseUrl -AdminApiKeySecretName $BuildMasterAdminApiKeySecretName
    $headers = @{ 'X-ApiKey' = $settings.ApiKey }
    $listUri = '{0}/api/applications/list' -f $settings.BaseUrl
    $purgeUri = '{0}/api/applications/purge?application={1}' -f $settings.BaseUrl, [Uri]::EscapeDataString($Name)
    $updateUri = '{0}/api/applications/update' -f $settings.BaseUrl
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $listUri" -Tag 'RestCall'
      $applications = Invoke-RestMethod -Uri $listUri -Method Post -Headers $headers -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $listUri" -Tag 'RestCall'
    } catch {
      $errorMessage = "Failed to list BuildMaster applications. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    } finally {
    }

    $existing = @($applications | Where-Object { $_.name -eq $Name -or $_.Name -eq $Name } | Select-Object -First 1)
    if ($existing.Count -eq 0) {
      $existing = @($applications | Where-Object { ([string]$_.name).Equals($Name, [System.StringComparison]::OrdinalIgnoreCase) -or ([string]$_.Name).Equals($Name, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
    }
    if ($existing.Count -eq 0) {
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $true
        Action          = 'Unchanged'
        ApplicationName = $Name
        ApplicationId   = $null
        ResponseSummary = "application '$Name' was not found"
      }
    }

    $target = "BuildMaster application '$Name'"
    $action = if ($DeactivateOnly) { 'Deactivate' } else { 'Purge' }
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $false
        Action          = 'WhatIf'
        ApplicationName = $Name
        ApplicationId   = $existing[0].id
        ResponseSummary = "WhatIf: planned $($action.ToLowerInvariant()) of $target"
      }
    }

    if ($DeactivateOnly) {
      try {
        $body = @{ name = $Name; active = $false } | ConvertTo-Json -Depth 5
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $updateUri" -Tag 'RestCall'
        $response = Invoke-RestMethod -Uri $updateUri -Method Post -Headers $headers -ContentType 'application/json' -Body $body -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $updateUri" -Tag 'RestCall'
      } catch {
        $errorMessage = "Failed to deactivate BuildMaster application '$Name'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      } finally {
      }

      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $true
        Action          = 'Deactivated'
        ApplicationName = $Name
        ApplicationId   = $response.id
        ResponseSummary = "deactivated application '$Name'"
      }
    }

    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $purgeUri" -Tag 'RestCall'
      Invoke-RestMethod -Uri $purgeUri -Method Post -Headers $headers -ErrorAction Stop | Out-Null
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $purgeUri" -Tag 'RestCall'
    } catch {
      $errorMessage = "Failed to purge BuildMaster application '$Name'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    } finally {
    }

    return [PSCustomObject]@{
      OperationName   = $fn
      Succeeded       = $true
      Action          = 'Purged'
      ApplicationName = $Name
      ApplicationId   = $existing[0].id
      ResponseSummary = "purged application '$Name'"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
