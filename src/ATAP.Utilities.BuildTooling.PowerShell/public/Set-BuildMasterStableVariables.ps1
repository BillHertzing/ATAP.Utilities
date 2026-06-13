function Set-BuildMasterStableVariables {
  <#
  .SYNOPSIS
    DEPRECATED. Sets the permanent (stable) BuildMaster Application Variables for all apps.
    Use Set-BuildMasterApplicationVariables instead.
    This cmdlet will be removed in Sprint 0008.
  .DESCRIPTION
    One-time-per-environment setup cmdlet. Uses the BuildMaster Variables REST
    API (POST /api/variables/application/{app}/{var}) to set 13 stable
    application variables for each application in -Applications:

      Permanent SQL Server instance references (3):
        IntegrationSqlInstance  — e.g. 'utat022\Integration'
        QASqlInstance           — e.g. 'utat022\QA'
        ProductionSqlInstance   — e.g. 'utat022\Production'

      ProGet feed names (5 NuGet, 5 PowerShellGet) and their default URLs (10):
        NuGetFeedName_Experimental  / NuGetFeedUrl_Experimental
        NuGetFeedName_Development   / NuGetFeedUrl_Development
        NuGetFeedName_Integration   / NuGetFeedUrl_Integration
        NuGetFeedName_QA            / NuGetFeedUrl_QA
        NuGetFeedName_Stable        / NuGetFeedUrl_Stable
        PowerShellGetFeedName_Experimental  / PowerShellGetFeedUrl_Experimental
        PowerShellGetFeedName_Development   / PowerShellGetFeedUrl_Development
        PowerShellGetFeedName_Integration   / PowerShellGetFeedUrl_Integration
        PowerShellGetFeedName_QA            / PowerShellGetFeedUrl_QA
        PowerShellGetFeedName_Stable        / PowerShellGetFeedUrl_Stable

    ProGet feed metadata is resolved via Resolve-ProGetFeedFromSettings, which
    reads the ProGetFeedCollection from $global:Settings per Explainer 0111.
    SQL Server host/instance values are resolved via Resolve-BuildToolingSettingValue,
    which also reads from $global:Settings. The previous dependency on
    Get-ATAPIACConstant and ATAP.IAC PSD1 fallbacks has been removed.

    This cmdlet is idempotent: re-running it updates all values to current
    settings, which is safe and useful after a ProGet host or SQL server change.

    Resolves the API key secret name via Get-PVal (default
    'BuildMaster.Admin.API.Key') and reads the key value with Get-SecretATAP.

    ** DEPRECATED ** Use Set-BuildMasterApplicationVariables instead.
    This cmdlet will be removed in Sprint 0008.

  .PARAMETER Applications
    List of BuildMaster application names to update.
    Defaults to @('AceCommander', 'ATAP.Utilities').
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server.
    Defaults to 'http://localhost:50017'.
  .OUTPUTS
    PSCustomObject with variablesSet (array of 'appName/varName' strings) and
    errors (array of error message strings) fields.
  .EXAMPLE
    # One-time setup on a new BuildMaster installation
    Set-BuildMasterStableVariables
  .EXAMPLE
    # Update after changing the ProGet host address
    Set-BuildMasterStableVariables -BuildMasterBaseUrl 'http://buildmaster.corp:50017'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
    Phase 3C — T-31 (7.2-2 BuildMaster stable application variables)
    Migrated off deprecated Get-ATAPIACConstant in favor of
    Resolve-ProGetFeedFromSettings and Resolve-BuildToolingSettingValue.
    DEPRECATED: Use Set-BuildMasterApplicationVariables instead.
    This cmdlet will be removed in Sprint 0008.
  .LINK
    Set-BuildMasterApplicationVariables
    Set-BuildMasterSprintVariables
    Resolve-ProGetFeedFromSettings
    Resolve-BuildToolingSettingValue
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string[]]$Applications = @('AceCommander', 'ATAP.Utilities'),

    [string]$BuildMasterBaseUrl,

    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message 'DEPRECATED: Use Set-BuildMasterApplicationVariables instead. This cmdlet will be removed in Sprint 0008.'

    $BuildMasterBaseUrl = Get-PVal -ParameterName 'BuildMasterBaseUrl' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterBaseUrl

    $BuildMasterAdminApiKeySecretName = Get-PVal -ParameterName 'BuildMasterAdminApiKeySecretName' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterAdminApiKeySecretName
    # Retrieve the BuildMaster admin API key value via Get-SecretATAP using the
    # resolved secret name. The key value is never logged.
    $apiKey = $null
    $secretErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($fieldName in @($null, 'token', 'key', 'password')) {
      try {
        $candidate = if ($null -eq $fieldName) {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
        } else {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -SecretField $fieldName -ErrorAction Stop
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { $apiKey = [string]$candidate; break }
      } catch {
        $fieldLabel = if ($null -eq $fieldName) { '<default>' } else { $fieldName }
        $secretErrors.Add("${fieldLabel}: $($_.Exception.Message)") | Out-Null
      }
    }
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      $detail = if ($secretErrors.Count -gt 0) { " Last error: $($secretErrors[$secretErrors.Count - 1])" } else { '' }
      throw "Unable to resolve the BuildMaster admin API key from secret '$BuildMasterAdminApiKeySecretName' via Get-SecretATAP. Cannot set BuildMaster stable variables.$detail"
    }

    $headers = @{
      'X-ApiKey'     = $apiKey
      'Content-Type' = 'text/plain'
    }
  }

  process {
    $stableVarMap = [ordered]@{}

    # -----------------------------------------------------------------------
    # Resolve SQL instance variable values from $global:Settings via
    # Resolve-BuildToolingSettingValue.
    # Combine host + '\' + instance name → e.g. 'utat022\Integration'
    # -----------------------------------------------------------------------
    try {
      $intHost = Resolve-BuildToolingSettingValue -Name 'IntegrationDBHost'
      $intInst = Resolve-BuildToolingSettingValue -Name 'IntegrationSQLInstance'
      $stableVarMap['IntegrationSqlInstance'] = "$intHost\$intInst"

      $qaHost = Resolve-BuildToolingSettingValue -Name 'QADBHost'
      $qaInst = Resolve-BuildToolingSettingValue -Name 'QASQLInstance'
      $stableVarMap['QASqlInstance'] = "$qaHost\$qaInst"

      $prodHost = Resolve-BuildToolingSettingValue -Name 'ProductionDBHost'
      $prodInst = Resolve-BuildToolingSettingValue -Name 'ProductionSQLInstance'
      $stableVarMap['ProductionSqlInstance'] = "$prodHost\$prodInst"
    } catch {
      throw "Failed to resolve SQL instance settings: $($_.Exception.Message)"
    }

    # -----------------------------------------------------------------------
    # Resolve the 10 feed name + URL pairs from $global:Settings via
    # Resolve-ProGetFeedFromSettings. The BuildMaster variable names preserve
    # PascalCase tier suffixes; the resolver accepts canonical lowercase tiers.
    # -----------------------------------------------------------------------
    $feedTypeMap = [ordered]@{
      'NuGet'         = 'nuget'
      'PowerShellGet' = 'powershellget'
    }
    $tierMap = [ordered]@{
      'Experimental' = 'experimental'
      'Development'  = 'development'
      'Integration'  = 'integration'
      'QA'           = 'qa'
      'Stable'       = 'stable'
    }

    foreach ($feedTypeKvp in $feedTypeMap.GetEnumerator()) {
      foreach ($tierKvp in $tierMap.GetEnumerator()) {
        $varSuffix = "$($feedTypeKvp.Key)_$($tierKvp.Key)"
        try {
          $feed = Resolve-ProGetFeedFromSettings -FeedType $feedTypeKvp.Value -Tier $tierKvp.Value
          $stableVarMap["$($feedTypeKvp.Key)FeedName_$($tierKvp.Key)"] = $feed.FeedName
          $stableVarMap["$($feedTypeKvp.Key)FeedUrl_$($tierKvp.Key)"] = $feed.EndpointUri
        } catch {
          throw "Failed to resolve ProGet feed for '$varSuffix': $($_.Exception.Message)"
        }
      }
    }

    # -----------------------------------------------------------------------
    # Set all stable variables for each application
    # -----------------------------------------------------------------------
    $variablesSet = [System.Collections.ArrayList]::new()
    $errors = [System.Collections.ArrayList]::new()

    foreach ($appName in $Applications) {
      foreach ($varName in $stableVarMap.Keys) {
        $varValue = $stableVarMap[$varName]
        $escapedApp = [Uri]::EscapeDataString($appName)
        $escapedVar = [Uri]::EscapeDataString($varName)
        $uri = "$BuildMasterBaseUrl/api/variables/application/$escapedApp/$escapedVar"

        try {
          if ($PSCmdlet.ShouldProcess("$appName/$varName", "Set BuildMaster application variable to '$varValue'")) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Calling $uri" -Tag 'RestCall'
            Invoke-RestMethod `
              -Uri $uri `
              -Method Post `
              -Headers $headers `
              -Body $varValue `
              -ErrorAction Stop | Out-Null
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Successfully returned from $uri" -Tag 'RestCall'

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Set $appName/$varName = '$varValue'"
            [void]$variablesSet.Add("$appName/$varName")
          }
        } catch {
          $errMsg = "Failed to set $appName/$varName. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
          [void]$errors.Add($errMsg)
        }
      }
    }

    return [PSCustomObject]@{
      variablesSet = $variablesSet.ToArray()
      errors       = $errors.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
