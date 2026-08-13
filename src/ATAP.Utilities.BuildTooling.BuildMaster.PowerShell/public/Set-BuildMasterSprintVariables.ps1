function Set-BuildMasterSprintVariables {
  <#
  .SYNOPSIS
    Sets BuildMaster Application Variables for a new sprint.
  .DESCRIPTION
    Uses the BuildMaster Variables REST API
    (POST /api/variables/application/{app}/{var}) to set sprint-scoped
    application variables for each BuildMaster application that belongs to a
    repository participating in the current sprint:

      SprintNumber      — e.g. '0006'
      UserName          — e.g. 'whertzing'
      SprintBranchName  — e.g. '98-Sprint-0006-work-items'
      SourcePath        — e.g. the source path for each application's build (FSS-26b)

    These variables are consumed by the 5-Stage OtterScript build plans to
    identify which source branch to check out, which sprint context applies,
    and where to find source files for the build.
    They are cleared at sprint-end by Clear-BuildMasterSprintVariables.

    Application targeting (Task 10.12): a single repository can map to one or
    more BuildMaster applications whose names do NOT match the repository name.
    The ATAP.Utilities repository, for example, builds two BuildMaster
    applications — 'ATAP.Utilities-CSharp' and 'ATAP.Utilities-PowerShell' —
    so POSTing to '/api/variables/application/ATAP.Utilities/...' returns
    404 Not Found. This cmdlet therefore:
      * drives the worked application set from the sprint's ACTUAL
        repositories (the keys of -SprintBranchNames / -SourcePaths, plus any
        explicit -Applications), never a fixed list; and
      * resolves each repository to its real BuildMaster application name(s)
        via -RepositoryApplicationMap. Repositories that participate in the
        sprint but have no BuildMaster application (e.g. _Planning,
        SharedVSCode) are not present in the map and are skipped, so no
        variables are pushed for repositories outside the build system.

    Resolves the API key secret name via Get-PVal (default
    'BuildMaster.Admin.API.Key.utat01') and reads the key value with Get-SecretATAP.

  .PARAMETER SprintNumber
    The zero-padded four-character sprint number, e.g. '0006'.
  .PARAMETER Username
    The developer's Windows username. Defaults to $env:USERNAME.
  .PARAMETER SprintBranchNames
    Optional hashtable mapping repository name to the sprint branch name for
    that repository.
    e.g. @{ 'AceCommander' = '42-Sprint-0006-work-items'; 'ATAP.Utilities' = '98-Sprint-0006-work-items' }
    The keys are repository names (as discovered from the sprint board), NOT
    BuildMaster application names. If a repository key is absent, SprintBranchName
    is set to the generic fallback '$SprintNumber-Sprint-work-items'.
  .PARAMETER SourcePaths
    Optional hashtable mapping repository name to the source path for that
    repository's build (FSS-26b). Keys are repository names. When present, a
    'SourcePath' variable is set for every BuildMaster application that the
    repository maps to.
  .PARAMETER RepositoryApplicationMap
    Hashtable mapping a repository name to the BuildMaster application name(s)
    that repository builds. One repository may map to several applications.
    Default:
      @{
        'AceCommander'   = @('AceCommander')
        'ATAP.Utilities' = @('ATAP.Utilities-CSharp', 'ATAP.Utilities-PowerShell')
      }
    A repository that is in the sprint but absent from this map is skipped
    (it has no BuildMaster application), which is how out-of-build repositories
    are kept from receiving variables.
  .PARAMETER Applications
    Optional list of ADDITIONAL repository names to target beyond those implied
    by -SprintBranchNames / -SourcePaths. Each entry is resolved through
    -RepositoryApplicationMap exactly like a discovered repository. Defaults to
    an empty list — the worked set is driven by the sprint's actual repositories
    rather than a fixed list.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server.
    Defaults to 'https://utat022:50017'.
  .OUTPUTS
    PSCustomObject with variablesSet (array of 'appName/varName' strings),
    skippedRepositories (array of repo names with no BuildMaster application),
    and errors (array of error message strings) fields.
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
    FSS-55: Un-deprecated. Actively maintained and used in New-SprintStage2.
    Task 10.12: targeting is now driven by the sprint's real repositories and
    each repository's true BuildMaster application name(s), fixing the 404s for
    ATAP.Utilities and the spurious targeting of AceCommander when it is not in
    the sprint.
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

    [hashtable]$SourcePaths = @{},

    [hashtable]$RepositoryApplicationMap = @{
      'AceCommander'   = @('AceCommander')
      'ATAP.Utilities' = @('ATAP.Utilities-CSharp', 'ATAP.Utilities-PowerShell')
    },

    [string[]]$Applications = @(),

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
      throw "Unable to resolve the BuildMaster admin API key from secret '$BuildMasterAdminApiKeySecretName' via Get-SecretATAP. Cannot set BuildMaster variables.$detail"
    }

    $headers = @{
      'X-ApiKey'     = $apiKey
      'Content-Type' = 'text/plain'
    }
  }

  process {
    $variablesSet = [System.Collections.ArrayList]::new()
    $skippedRepositories = [System.Collections.ArrayList]::new()
    $errors = [System.Collections.ArrayList]::new()

    # Drive the worked set from the sprint's ACTUAL repositories (Task 10.12):
    # the union of the repositories named in -SprintBranchNames, -SourcePaths,
    # and any explicit -Applications. This replaces the previous fixed
    # @('AceCommander', 'ATAP.Utilities') list so repositories outside the
    # sprint never receive variables.
    $sprintRepoNames = [System.Collections.Generic.List[string]]::new()
    foreach ($repoSource in @($SprintBranchNames.Keys, $SourcePaths.Keys, $Applications)) {
      foreach ($name in $repoSource) {
        if (-not [string]::IsNullOrWhiteSpace($name) -and -not $sprintRepoNames.Contains($name)) {
          [void]$sprintRepoNames.Add($name)
        }
      }
    }

    if ($sprintRepoNames.Count -eq 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message 'No sprint repositories supplied (SprintBranchNames/SourcePaths/Applications all empty) — no BuildMaster variables to set.'
    }

    foreach ($repoName in $sprintRepoNames) {
      # Resolve this repository to its real BuildMaster application name(s).
      # A repository absent from the map has no BuildMaster application and is
      # skipped — this is how out-of-build repos (e.g. _Planning, SharedVSCode)
      # are kept from receiving variables and from causing 404s.
      if (-not $RepositoryApplicationMap.ContainsKey($repoName)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Repository '$repoName' has no BuildMaster application in RepositoryApplicationMap — skipping (no variables set)."
        [void]$skippedRepositories.Add($repoName)
        continue
      }

      $appNames = @($RepositoryApplicationMap[$repoName]) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
      if ($appNames.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Repository '$repoName' mapped to an empty BuildMaster application list — skipping."
        [void]$skippedRepositories.Add($repoName)
        continue
      }

      # Determine the sprint branch name for this repository.
      $branchName = if ($SprintBranchNames.ContainsKey($repoName)) {
        $SprintBranchNames[$repoName]
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
          -Message "No SprintBranchName entry for '$repoName' — using fallback '$SprintNumber-Sprint-work-items'"
        "$SprintNumber-Sprint-work-items"
      }

      $varMap = [ordered]@{
        SprintNumber     = $SprintNumber
        UserName         = $Username
        SprintBranchName = $branchName
      }

      if ($SourcePaths.ContainsKey($repoName)) {
        $varMap['SourcePath'] = $SourcePaths[$repoName]
      }

      foreach ($appName in $appNames) {
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
                -Message "Set $appName/$varName = '$varValue' (repo '$repoName')"
              [void]$variablesSet.Add("$appName/$varName")
            }
          } catch {
            $errMsg = "Failed to set $appName/$varName (repo '$repoName'). Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
            [void]$errors.Add($errMsg)
          }
        }
      }
    }

    return [PSCustomObject]@{
      variablesSet        = $variablesSet.ToArray()
      skippedRepositories = $skippedRepositories.ToArray()
      errors              = $errors.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
