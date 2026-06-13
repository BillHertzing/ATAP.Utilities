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
    'BuildMaster.Admin.API.Key') and reads the key value with Get-SecretATAP.

    Deletion is idempotent — if a variable does not exist the API returns 404,
    which this cmdlet treats as a successful no-op (already deleted).

  .PARAMETER Applications
    List of BuildMaster application names to clear.
    Defaults to @('AceCommander', 'ATAP.Utilities').
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server.
    Defaults to 'http://localhost:50017'.
  .PARAMETER BuildMasterAdminApiKeySecretName
    ATAP secret name for the BuildMaster admin API key. Resolved via Get-PVal
    (default 'BuildMaster.Admin.API.Key'); value read with Get-SecretATAP.
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
    [string[]]$Applications = @('AceCommander', 'ATAP.Utilities'),

    [string]$BuildMasterBaseUrl = 'http://localhost:50017',

    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key'
  )

  begin {
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

    foreach ($appName in $Applications) {
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
