function Set-BuildMasterStableVariables {
  <#
  .SYNOPSIS
    Sets the permanent (stable) BuildMaster Application Variables for all apps.
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

    Reads the API key from the BUILDMASTER_ADMIN_API_KEY environment variable
    (User scope preferred, then Process scope).

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
  .LINK
    Set-BuildMasterSprintVariables
    Resolve-ProGetFeedFromSettings
    Resolve-BuildToolingSettingValue
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string[]]$Applications = @('AceCommander', 'ATAP.Utilities'),

    [string]$BuildMasterBaseUrl
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Load Helpers
    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1"
      }
    }
    catch {
      $errorMessage = "Failed to load Get-ParameterValueFromNeoConfigurationRoot function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    $BuildMasterBaseUrl = Get-PVal -ParameterName 'BuildMasterBaseUrl' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterBaseUrl

    $apiKey = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'User')
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      $apiKey = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      throw 'BUILDMASTER_ADMIN_API_KEY is not set at User or Process scope. Cannot set BuildMaster stable variables.'
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
