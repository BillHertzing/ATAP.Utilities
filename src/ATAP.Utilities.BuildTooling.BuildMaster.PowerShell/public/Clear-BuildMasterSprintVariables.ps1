function Clear-BuildMasterSprintVariables {
  <#
  .SYNOPSIS
    Deletes the sprint-scoped BuildMaster Application Variables at sprint-end.
  .DESCRIPTION
    Uses the BuildMaster Variables REST API
    (DELETE /api/variables/application/{app}/{var}) to remove the three
    sprint-scoped application variables that were set by
    Set-BuildMasterSprintVariables at sprint start:

      SprintNumber
      UserName
      SprintBranchName

    Call this cmdlet during the sprint-end teardown sequence (SprintEndAgent
    Step 10.5) after workTrees have been removed.

    Resolves the API key secret name via Get-PVal (default
    'BuildMaster.Admin.API.Key.utat01') and reads the key value with Get-SecretATAP.

    Deletion is idempotent — if a variable does not exist the API returns 404,
    which this cmdlet treats as a successful no-op (already deleted).

    Application targeting (Task 10.12): the worked application set is the union
    of every BuildMaster application named in -RepositoryApplicationMap (so the
    ATAP.Utilities repository resolves to both 'ATAP.Utilities-CSharp' and
    'ATAP.Utilities-PowerShell') plus any explicit -Applications. This keeps
    Clear in lock-step with Set-BuildMasterSprintVariables, which writes to the
    same real application names; clearing the bare 'ATAP.Utilities' name would
    404 and leave the actual sprint variables behind.

  .PARAMETER RepositoryApplicationMap
    Hashtable mapping a repository name to the BuildMaster application name(s)
    that repository builds. Every application named in the map is cleared.
    Default:
      @{
        'AceCommander'   = @('AceCommander')
        'ATAP.Utilities' = @('ATAP.Utilities-CSharp', 'ATAP.Utilities-PowerShell')
      }
  .PARAMETER Applications
    Optional list of ADDITIONAL BuildMaster application names to clear beyond
    those resolved from -RepositoryApplicationMap. Defaults to an empty list.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server.
    Defaults to 'http://localhost:50017'.
  .PARAMETER BuildMasterAdminApiKeySecretName
    ATAP secret name for the BuildMaster admin API key. Resolved via Get-PVal
    (default 'BuildMaster.Admin.API.Key.utat01'); value read with Get-SecretATAP.
  .OUTPUTS
    PSCustomObject with variablesCleared (array of 'appName/varName' strings)
    and errors (array of error message strings) fields.
  .EXAMPLE
    Clear-BuildMasterSprintVariables
  .EXAMPLE
    # Target a different BuildMaster instance
    Clear-BuildMasterSprintVariables -BuildMasterBaseUrl 'http://buildmaster.corp:50017'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
    Phase 3C — T-31 (7.2-1 BuildMaster sprint application variables teardown)
  .LINK
    Set-BuildMasterSprintVariables
    SprintEndAgent
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [hashtable]$RepositoryApplicationMap = @{
      'AceCommander'   = @('AceCommander')
      'ATAP.Utilities' = @('ATAP.Utilities-CSharp', 'ATAP.Utilities-PowerShell')
    },

    [string[]]$Applications = @(),

    [string]$BuildMasterBaseUrl = 'http://localhost:50017',

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

    # Retrieve the BuildMaster admin API key value via Get-SecretATAP using the
    # resolved secret name. The key value is never logged.
    $apiKey = $null
    $secretErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($fieldName in @($null, 'token', 'key', 'password')) {
      try {
        $candidate = if ($null -eq $fieldName) {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
        } else {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretField $fieldName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { $apiKey = [string]$candidate; break }
      } catch {
        $fieldLabel = if ($null -eq $fieldName) { '<default>' } else { $fieldName }
        $secretErrors.Add("${fieldLabel}: $($_.Exception.Message)") | Out-Null
      }
    }
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      $detail = if ($secretErrors.Count -gt 0) { " Last error: $($secretErrors[$secretErrors.Count - 1])" } else { '' }
      throw "Unable to resolve the BuildMaster admin API key from secret '$BuildMasterAdminApiKeySecretName' via Get-SecretATAP. Cannot clear BuildMaster variables.$detail"
    }

    $headers = @{ 'X-ApiKey' = $apiKey }

    # The three sprint-scoped variable names
    $sprintVarNames = @('SprintNumber', 'UserName', 'SprintBranchName')
  }

  process {
    $variablesCleared = [System.Collections.ArrayList]::new()
    $errors = [System.Collections.ArrayList]::new()

    # Resolve the worked application set (Task 10.12): every BuildMaster
    # application named in the repository map, unioned with any explicit
    # -Applications. This matches the real application names that
    # Set-BuildMasterSprintVariables writes to.
    $targetApplications = [System.Collections.Generic.List[string]]::new()
    foreach ($mappedApps in $RepositoryApplicationMap.Values) {
      foreach ($appName in @($mappedApps)) {
        if (-not [string]::IsNullOrWhiteSpace($appName) -and -not $targetApplications.Contains($appName)) {
          [void]$targetApplications.Add($appName)
        }
      }
    }
    foreach ($appName in $Applications) {
      if (-not [string]::IsNullOrWhiteSpace($appName) -and -not $targetApplications.Contains($appName)) {
        [void]$targetApplications.Add($appName)
      }
    }

    foreach ($appName in $targetApplications) {
      foreach ($varName in $sprintVarNames) {
        $escapedApp = [Uri]::EscapeDataString($appName)
        $escapedVar = [Uri]::EscapeDataString($varName)
        $uri = "$BuildMasterBaseUrl/api/variables/application/$escapedApp/$escapedVar"

        try {
          if ($PSCmdlet.ShouldProcess("$appName/$varName", 'Delete BuildMaster application variable')) {
            try {
              Invoke-RestMethod `
                -Uri $uri `
                -Method Delete `
                -Headers $headers `
                -ErrorAction Stop | Out-Null
            } catch {
              # 404 = variable did not exist — treat as success (already cleared)
              if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 404) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
                  -Message "$appName/$varName not found (already cleared or never set) — skipping"
              } else {
                throw
              }
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Cleared $appName/$varName"
            [void]$variablesCleared.Add("$appName/$varName")
          }
        } catch {
          $errMsg = "Failed to clear $appName/$varName. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
          [void]$errors.Add($errMsg)
        }
      }
    }

    return [PSCustomObject]@{
      variablesCleared = $variablesCleared.ToArray()
      errors           = $errors.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
