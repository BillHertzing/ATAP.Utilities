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

    Reads the API key from the BUILDMASTER_ADMIN_API_KEY environment variable
    (User scope preferred, then Process scope).

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

    [string]$BuildMasterBaseUrl
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message 'DEPRECATED: Use Set-BuildMasterApplicationVariables instead. This cmdlet will be removed in Sprint 0008.'

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
      throw 'BUILDMASTER_ADMIN_API_KEY is not set at User or Process scope. Cannot set BuildMaster variables.'
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
