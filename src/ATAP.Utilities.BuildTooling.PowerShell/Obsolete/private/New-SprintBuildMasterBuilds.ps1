function New-SprintBuildMasterBuilds {
  <#
  .SYNOPSIS
    Creates BuildMaster build configurations for sprint environments.
  .DESCRIPTION
    DRAFT IMPLEMENTATION — BuildMaster build creation via PowerShell has not
    yet been tested. This function is commented-out / skipped at runtime and
    exists as a scaffold for future implementation.

    Creates builds for AceCommander and ATAP.Utilities, setting the
    AceCommanderSourcePath / ATAPUtilitiesSourcePath application variables
    to the appropriate sprint worktree paths.
  .PARAMETER SprintNumber
    The sprint number (e.g., '0005').
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server (e.g., 'http://localhost:50001').
  .PARAMETER Username
    The current user's name, used in the Development environment suffix.
  .OUTPUTS
    PSCustomObject with createdBuilds, errors, and progetFeedMapping fields.
  .EXAMPLE
    New-SprintBuildMasterBuilds -SprintNumber '0006' -GitRoot 'C:\Dropbox\whertzing\GitHub' `
      -BuildMasterBaseUrl 'http://localhost:50001' -Username 'whertzing'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
    TODO: Test against live BuildMaster server.
    TODO: Define integration between BuildMaster package I/O and ProGet feeds.
  .LINK
    New-SprintStage2
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SprintNumber,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$GitRoot,

    [string]$BuildMasterBaseUrl,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Username
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $BuildMasterBaseUrl = Get-PVal -ParameterName 'BuildMasterBaseUrl' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterBaseUrl

    # Read API key from the ATAP secret store (never hard-code)
    $apiKey = Get-SecretATAP -SecretName 'BuildMaster.Admin.API.Key.utat01'
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      throw "Unable to resolve the BuildMaster admin API key from secret 'BuildMaster.Admin.API.Key.utat01' via Get-SecretATAP. Cannot create BuildMaster builds."
    }
  }

  process {
    # ---------------------------------------------------------------
    # DRAFT / COMMENTED OUT — BuildMaster API integration is not yet
    # validated. Uncomment and adjust when ready to test.
    # ---------------------------------------------------------------

    $environments = @(
      # Single ephemeral sprint instance: Sprint${SprintNumber}_${Username}
      # WorTreeSuffix aligns with the sprint worktree naming convention: {RepoName}-wt-{IssueNum}-sprint-{NNNN}-work-items
      @{ Suffix = "_${Username}"; WorTreeSuffix = 'work-items' }
    )

    $applications = @(
      @{
        Name     = 'AceCommander'
        Variable = 'AceCommanderSourcePath'
      }
      @{
        Name     = 'ATAP.Utilities'
        Variable = 'ATAPUtilitiesSourcePath'
      }
    )

    $headers = @{
      'X-ApiKey'     = $apiKey
      'Content-Type' = 'application/json'
    }

    $createdBuilds = [System.Collections.ArrayList]::new()
    $buildErrors = [System.Collections.ArrayList]::new()

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message 'BuildMaster sprint build creation is DRAFT — skipping actual API calls'

    <#
    # === BEGIN DRAFT BUILDMASTER API CALLS ===
    # PLACEHOLDER: The BuildMaster Native API endpoint for creating builds
    # and setting application variables needs to be verified against the
    # actual BuildMaster version running on this server.

    foreach ($app in $applications) {
      foreach ($env in $environments) {
        $buildName = "Sprint${SprintNumber}$($env.Suffix)"

        # Compute the source path pointing to the sprint worktree
        # e.g. C:\Dropbox\whertzing\GitHub\AceCommander-wt-NN-sprint-NNNN-testing
        # PLACEHOLDER: The worktree naming for non-work-items branches is TBD.
        # For now, use the work-items worktree path as a starting reference.
        $sourcePath = Join-Path $GitRoot "$($app.Name)-wt-sprint-$SprintNumber-$($env.WorTreeSuffix)"

        # Set application variable
        $varBody = @{
          applicationName = $app.Name
          variableName    = $app.Variable
          variableValue   = $sourcePath
          environmentName = $buildName
        } | ConvertTo-Json

        $varUri = "$BuildMasterBaseUrl/api/variables/application/set"

        try {
          if ($PSCmdlet.ShouldProcess("$($app.Name)/$buildName", "Set $($app.Variable) = $sourcePath")) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Calling $varUri" -Tag 'RestCall'
            Invoke-RestMethod -Uri $varUri -Method Post -Headers $headers -Body $varBody
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Successfully returned from $varUri" -Tag 'RestCall'

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Set $($app.Variable) for $($app.Name)/$buildName -> $sourcePath"
            [void]$createdBuilds.Add("$($app.Name)/$buildName")
          }
        } catch {
          $errMsg = "Failed to configure BuildMaster $($app.Name)/$buildName. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
          [void]$buildErrors.Add($errMsg)
        }

        # PLACEHOLDER: Create the actual build plan / pipeline entry
        # TODO: Determine the BuildMaster API call for creating a new
        #       build (release, pipeline, etc.) and implement here.
        # TODO: Define how BuildMaster build outputs (packages) map to
        #       the ProGet sprint feeds created by New-ProGetSprintFeeds.
      }
    }
    # === END DRAFT BUILDMASTER API CALLS ===
    #>

    return [PSCustomObject]@{
      createdBuilds     = $createdBuilds.ToArray()
      errors            = $buildErrors.ToArray()
      # PLACEHOLDER: Add feed-to-build mapping when ProGet/BuildMaster
      # integration is defined.
      progetFeedMapping = @{}
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
