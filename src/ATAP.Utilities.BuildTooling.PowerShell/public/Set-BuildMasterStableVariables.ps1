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

    Values are resolved via Get-ATAPIACConstant (falls back to direct
    Import-PowerShellDataFile of HostConstants.psd1 / FeedConstants.psd1 in the
    sibling ATAP.IAC repository when the cmdlet is not available).

    This cmdlet is idempotent: re-running it updates all values to current
    constants, which is safe and useful after a ProGet host or SQL server change.

    Reads the API key from the BUILDMASTER_API_KEY environment variable
    (User scope preferred, then Process scope).

  .PARAMETER Applications
    List of BuildMaster application names to update.
    Defaults to @('AceCommander', 'ATAP.Utilities').
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server.
    Defaults to 'http://localhost:50001'.
  .OUTPUTS
    PSCustomObject with variablesSet (array of 'appName/varName' strings) and
    errors (array of error message strings) fields.
  .EXAMPLE
    # One-time setup on a new BuildMaster installation
    Set-BuildMasterStableVariables
  .EXAMPLE
    # Update after changing the ProGet host address
    Set-BuildMasterStableVariables -BuildMasterBaseUrl 'http://buildmaster.corp:8622'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
    Phase 3C — T-31 (7.2-2 BuildMaster stable application variables)
  .LINK
    Set-BuildMasterSprintVariables
    Get-ATAPIACConstant
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string[]]$Applications = @('AceCommander', 'ATAP.Utilities'),

    [string]$BuildMasterBaseUrl = 'http://localhost:50001'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $apiKey = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_API_KEY', 'User')
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      $apiKey = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_API_KEY', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      throw 'BUILDMASTER_API_KEY is not set at User or Process scope. Cannot set BuildMaster stable variables.'
    }

    $headers = @{
      'X-ApiKey'     = $apiKey
      'Content-Type' = 'text/plain'
    }

    # -----------------------------------------------------------------------
    # Local helper: resolve a constant by name via Get-ATAPIACConstant if
    # available, otherwise walk up to the sibling ATAP.IAC repo and load
    # the .psd1 files directly. This mirrors the pattern in Resolve-FeedName.ps1.
    # -----------------------------------------------------------------------
    function Resolve-Constant {
      param([string]$Name)

      if (Get-Command 'Get-ATAPIACConstant' -ErrorAction SilentlyContinue) {
        return Get-ATAPIACConstant -Name $Name
      }

      # Fallback: locate ATAP.IAC sibling repo via git root
      $gitRoot = (git rev-parse --show-toplevel 2>$null)
      if ($gitRoot) {
        $parentDir = Split-Path -Parent $gitRoot
        $psd1Files = Get-ChildItem -Path $parentDir -Filter '*.psd1' -Recurse -Depth 4 `
          -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -match 'ATAP\.IAC.*[\\/]constants[\\/]' }
        foreach ($f in $psd1Files) {
          $data = Import-PowerShellDataFile -Path $f.FullName -ErrorAction SilentlyContinue
          if ($data -and $data.ContainsKey($Name)) {
            return $data[$Name]
          }
        }
      }

      throw "Cannot resolve constant '$Name' — Get-ATAPIACConstant not available and ATAP.IAC repo not found under '$parentDir'"
    }
  }

  process {
    # -----------------------------------------------------------------------
    # Resolve SQL instance variable values:
    # Combine host + '\' + instance name → e.g. 'utat022\Integration'
    # -----------------------------------------------------------------------
    $stableVarMap = [ordered]@{}

    try {
      $intHost = Resolve-Constant -Name 'IntegrationDBHost'
      $intInst = Resolve-Constant -Name 'IntegrationSQLInstance'
      $stableVarMap['IntegrationSqlInstance'] = "$intHost\$intInst"

      $qaHost  = Resolve-Constant -Name 'QADBHost'
      $qaInst  = Resolve-Constant -Name 'QASQLInstance'
      $stableVarMap['QASqlInstance'] = "$qaHost\$qaInst"

      $prodHost = Resolve-Constant -Name 'ProductionDBHost'
      $prodInst = Resolve-Constant -Name 'ProductionSQLInstance'
      $stableVarMap['ProductionSqlInstance'] = "$prodHost\$prodInst"
    } catch {
      throw "Failed to resolve SQL instance constants: $($_.Exception.Message)"
    }

    # -----------------------------------------------------------------------
    # Resolve the 10 feed name + URL pairs from FeedConstants.psd1
    # -----------------------------------------------------------------------
    $feedConstantNames = @(
      'NuGetFeedName_Experimental',  'NuGetFeedUrl_Experimental',
      'NuGetFeedName_Development',   'NuGetFeedUrl_Development',
      'NuGetFeedName_Integration',   'NuGetFeedUrl_Integration',
      'NuGetFeedName_QA',            'NuGetFeedUrl_QA',
      'NuGetFeedName_Stable',        'NuGetFeedUrl_Stable',
      'PowerShellGetFeedName_Experimental', 'PowerShellGetFeedUrl_Experimental',
      'PowerShellGetFeedName_Development',  'PowerShellGetFeedUrl_Development',
      'PowerShellGetFeedName_Integration',  'PowerShellGetFeedUrl_Integration',
      'PowerShellGetFeedName_QA',           'PowerShellGetFeedUrl_QA',
      'PowerShellGetFeedName_Stable',       'PowerShellGetFeedUrl_Stable'
    )

    foreach ($constName in $feedConstantNames) {
      try {
        $stableVarMap[$constName] = Resolve-Constant -Name $constName
      } catch {
        throw "Failed to resolve feed constant '$constName': $($_.Exception.Message)"
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
            Invoke-RestMethod `
              -Uri $uri `
              -Method Post `
              -Headers $headers `
              -Body $varValue `
              -ErrorAction Stop | Out-Null

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
