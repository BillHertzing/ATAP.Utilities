function Set-BuildMasterSprintVariables {
  <#
  .SYNOPSIS
    DEPRECATED. Sets BuildMaster Application Variables for a new sprint.
    Use Set-BuildMasterApplicationVariables instead.
    This cmdlet will be removed in Sprint 0008.
  .DESCRIPTION
    Uses the BuildMaster Variables REST API
    (POST /api/variables/application/{app}/{var}) to set three sprint-scoped
    application variables for each application in -Applications:

      SprintNumber     — e.g. '0006'
      UserName         — e.g. 'whertzing'
      SprintBranchName — e.g. '98-Sprint-0006-work-items'

    These variables are consumed by the 5-Stage OtterScript build plans to
    identify which source branch to check out and which sprint context applies.
    They are cleared at sprint-end by Clear-BuildMasterSprintVariables.

    Resolves the API key secret name via Get-PVal (default
    'BuildMaster.Admin.API.Key') and reads the key value with Get-SecretATAP.

    ** DEPRECATED ** Use Set-BuildMasterApplicationVariables instead.
    This cmdlet will be removed in Sprint 0008.

  .PARAMETER SprintNumber
    The zero-padded four-character sprint number, e.g. '0006'.
  .PARAMETER Username
    The developer's Windows username. Defaults to $env:USERNAME.
  .PARAMETER SprintBranchNames
    Optional hashtable mapping BuildMaster application name to the sprint
    branch name for that application.
    e.g. @{ 'AceCommander' = '42-Sprint-0006-work-items'; 'ATAP.Utilities' = '98-Sprint-0006-work-items' }
    If an application key is absent, SprintBranchName is set to the
    generic fallback '$SprintNumber-Sprint-work-items'.
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
    Set-BuildMasterSprintVariables -SprintNumber '0006' `
      -SprintBranchNames @{
        'AceCommander'   = '42-Sprint-0006-work-items'
        'ATAP.Utilities' = '98-Sprint-0006-work-items'
      }
  .EXAMPLE
    # WhatIf — see what would be set without making API calls
    Set-BuildMasterSprintVariables -SprintNumber '0006' -WhatIf
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
    Phase 3C — T-31 (7.2-1 BuildMaster sprint application variables)
    DEPRECATED: Use Set-BuildMasterApplicationVariables instead.
    This cmdlet will be removed in Sprint 0008.
  .LINK
    Set-BuildMasterApplicationVariables
    New-SprintStage2
    Clear-BuildMasterSprintVariables
    Set-BuildMasterStableVariables
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SprintNumber,

    [string]$Username = $env:USERNAME,

    [hashtable]$SprintBranchNames = @{},

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
          Get-SecretATAP -BuildMasterAdminApiKeySecretName $BuildMasterAdminApiKeySecretName -ErrorAction Stop
        } else {
          Get-SecretATAP -BuildMasterAdminApiKeySecretName $BuildMasterAdminApiKeySecretName -SecretField $fieldName -ErrorAction Stop
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { $apiKey = [string]$candidate; break }
      } catch {
        $fieldLabel = if ($null -eq $fieldName) { '<default>' } else { $fieldName }
        $secretErrors.Add("${fieldLabel}: $($_.Exception.Message)") | Out-Null
      }
    }
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      $detail = if ($secretErrors.Count -gt 0) { " Last error: $($secretErrors[$secretErrors.Count - 1])" } else { '' }
      throw "Unable to resolve the BuildMaster admin API key from secret '$BuildMasterAdminApiKeySecretName' via Get-SecretATAP. Cannot set BuildMaster variables.$detail"
    }

    $headers = @{
      'X-ApiKey'     = $apiKey
      'Content-Type' = 'text/plain'
    }
  }

  process {
    $variablesSet = [System.Collections.ArrayList]::new()
    $errors = [System.Collections.ArrayList]::new()

    foreach ($appName in $Applications) {
      # Determine the sprint branch name for this application
      $branchName = if ($SprintBranchNames.ContainsKey($appName)) {
        $SprintBranchNames[$appName]
      } else {
        "$SprintNumber-Sprint-work-items"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
          -Message "No SprintBranchName entry for '$appName' — using fallback '$SprintNumber-Sprint-work-items'"
      }

      $varMap = [ordered]@{
        SprintNumber     = $SprintNumber
        UserName         = $Username
        SprintBranchName = $branchName
      }

      foreach ($varName in $varMap.Keys) {
        $varValue = $varMap[$varName]
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
