function New-BuildMasterApplication {
  <#
  .SYNOPSIS
    Creates or updates a BuildMaster application through the Application
    Management API.
  .DESCRIPTION
    Creates a blank BuildMaster application with fully parameterized
    ApplicationInfo fields. If an application with the same name already
    exists, the cmdlet updates its mutable settings instead of creating a
    duplicate.

    The application is assigned to the default raft by default by sending a
    null raft value. Pass -Raft only when an operator intentionally overrides
    the default storage decision.

    The API key is resolved from -ApiKey, then $global:settings, then
    BUILDMASTER_ADMIN_API_KEY at Process or User scope.
  .PARAMETER Name
    The unique BuildMaster application name.
  .PARAMETER Description
    Optional application description.
  .PARAMETER GroupName
    Optional application group name. Use null or an empty string to leave the
    application ungrouped.
  .PARAMETER Active
    Whether the application should be active.
  .PARAMETER SetupTemplate
    Optional setup template name.
  .PARAMETER BuildNumberScheme
    Build number scheme. Valid values are Sequential, DateTimeBased, or Unique.
  .PARAMETER ReleaseUsage
    Release usage mode. Valid values are Required, Optional, or Disabled.
  .PARAMETER DefaultReleaseTemplate
    Optional default release template name.
  .PARAMETER AllowIssues
    Whether issue tracking is enabled for the application.
  .PARAMETER DisplayIssues
    Whether the Issues tab is displayed.
  .PARAMETER DisplayPipelines
    Whether the Pipelines tab is displayed.
  .PARAMETER DisplayScripts
    Whether the Scripts tab is displayed.
  .PARAMETER DisplayConfiguration
    Whether the Configuration tab is displayed.
  .PARAMETER DisplayDatabase
    Whether the Database tab is displayed.
  .PARAMETER BuildPageDescription
    Optional text displayed on the build page.
  .PARAMETER ArtifactUsage
    Artifact storage mode.
  .PARAMETER ArtifactAssetDirectory
    Asset directory secure resource name when ArtifactUsage is AssetDirectory.
  .PARAMETER Raft
    Optional raft name. Defaults to null, which uses BuildMaster's default raft.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server. Defaults to $global:settings,
    BUILDMASTER_BASE_URL, then http://localhost:8622.
  .PARAMETER ApiKey
    BuildMaster API key with Application Management permission.
  .OUTPUTS
    PSCustomObject describing the operation result.
  .EXAMPLE
    New-BuildMasterApplication -Name 'ATAP.Utilities-CSharp' `
      -Description 'ATAP.Utilities C# package pipeline.'
  .EXAMPLE
    New-BuildMasterApplication -Name 'AceCommander-ReleaseBundle' `
      -ReleaseUsage Required -DisplayDatabase $true -WhatIf
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    https://docs.inedo.com/docs/buildmaster-appmanagement-create
  .LINK
    https://docs.inedo.com/docs/buildmaster-appmanagement-update
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [string]$Description,

    [AllowNull()]
    [string]$GroupName,

    [bool]$Active = $true,

    [AllowNull()]
    [string]$SetupTemplate,

    [ValidateSet('Sequential', 'DateTimeBased', 'Unique')]
    [string]$BuildNumberScheme = 'Sequential',

    [ValidateSet('Required', 'Optional', 'Disabled')]
    [string]$ReleaseUsage = 'Required',

    [AllowNull()]
    [string]$DefaultReleaseTemplate,

    [bool]$AllowIssues = $false,

    [bool]$DisplayIssues = $false,

    [bool]$DisplayPipelines = $true,

    [bool]$DisplayScripts = $true,

    [bool]$DisplayConfiguration = $true,

    [bool]$DisplayDatabase = $false,

    [AllowNull()]
    [string]$BuildPageDescription,

    [ValidateSet('Default', 'None', 'FileSystem', 'AssetDirectory')]
    [string]$ArtifactUsage = 'Default',

    [AllowNull()]
    [string]$ArtifactAssetDirectory,

    [AllowNull()]
    [string]$Raft = $null,

    [string]$BuildMasterBaseUrl,

    [string]$ApiKey
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    function Resolve-BuildMasterApiSettings {
      param(
        [string]$BaseUrl,
        [string]$Key
      )

      $resolvedBaseUrl = $BaseUrl
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl) -and $null -ne $global:settings) {
        $settingsKey = 'BuildMasterBaseUrl'
        if ($null -ne $global:configRootKeys -and $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']) {
          $settingsKey = $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']
        }
        if ($global:settings.ContainsKey($settingsKey)) {
          $resolvedBaseUrl = [string]$global:settings[$settingsKey]
        }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) {
        $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process')
      }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) {
        $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User')
      }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) {
        $resolvedBaseUrl = 'http://localhost:50017'
      }

      $resolvedApiKey = $Key
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey) -and $null -ne $global:settings) {
        $settingsKey = 'BuildMasterAdminApiKey'
        if ($null -ne $global:configRootKeys -and $global:configRootKeys['BuildMasterAdminApiKeyConfigRootKey']) {
          $settingsKey = $global:configRootKeys['BuildMasterAdminApiKeyConfigRootKey']
        }
        if ($global:settings.ContainsKey($settingsKey)) {
          $resolvedApiKey = [string]$global:settings[$settingsKey]
        }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
        $resolvedApiKey = [Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'Process')
      }
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
        $resolvedApiKey = [Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'User')
      }
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
        throw 'Unable to resolve BuildMaster API key. Pass -ApiKey, set $global:settings.BuildMasterAdminApiKey, or define BUILDMASTER_ADMIN_API_KEY.'
      }

      return [PSCustomObject]@{
        BaseUrl = $resolvedBaseUrl.TrimEnd('/')
        ApiKey  = $resolvedApiKey
      }
    }

    function Test-BuildMasterApplicationMatches {
      param(
        [object]$Existing,
        [hashtable]$Desired
      )

      foreach ($key in $Desired.Keys) {
        if (-not ($Existing.PSObject.Properties.Name -contains $key)) {
          return $false
        }
        $existingValue = $Existing.$key
        $desiredValue = $Desired[$key]
        if ($null -eq $existingValue -and $null -eq $desiredValue) {
          continue
        }
        if ([string]$existingValue -ne [string]$desiredValue) {
          return $false
        }
      }
      return $true
    }

    $settings = Resolve-BuildMasterApiSettings -BaseUrl $BuildMasterBaseUrl -Key $ApiKey
    $headers = @{ 'X-ApiKey' = $settings.ApiKey }
    $listUri = '{0}/api/applications/list' -f $settings.BaseUrl
    $createUri = '{0}/api/applications/create' -f $settings.BaseUrl
    $updateUri = '{0}/api/applications/update' -f $settings.BaseUrl
  }

  process {
    $desired = [ordered]@{
      name                   = $Name
      description            = $Description
      groupName              = $GroupName
      active                 = $Active
      setupTemplate          = $SetupTemplate
      buildNumberScheme      = $BuildNumberScheme
      releaseUsage           = $ReleaseUsage
      defaultReleaseTemplate = $DefaultReleaseTemplate
      allowIssues            = $AllowIssues
      displayIssues          = $DisplayIssues
      displayPipelines       = $DisplayPipelines
      displayScripts         = $DisplayScripts
      displayConfiguration   = $DisplayConfiguration
      displayDatabase        = $DisplayDatabase
      buildPageDescription   = $BuildPageDescription
      artifactUsage          = $ArtifactUsage
      artifactAssetDirectory = $ArtifactAssetDirectory
      raft                   = if ([string]::IsNullOrWhiteSpace($Raft)) { $null } else { $Raft }
    }

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

    if ($existing.Count -gt 0) {
      if (Test-BuildMasterApplicationMatches -Existing $existing[0] -Desired $desired) {
        return [PSCustomObject]@{
          OperationName   = $fn
          Succeeded       = $true
          Action          = 'Unchanged'
          ApplicationName = $Name
          ApplicationId   = $existing[0].id
          ResponseSummary = "application '$Name' already matches desired state"
          Response        = $existing[0]
        }
      }

      $target = "BuildMaster application '$Name'"
      if (-not $PSCmdlet.ShouldProcess($target, 'Update')) {
        return [PSCustomObject]@{
          OperationName   = $fn
          Succeeded       = $false
          Action          = 'WhatIf'
          ApplicationName = $Name
          ApplicationId   = $existing[0].id
          ResponseSummary = "WhatIf: planned update of $target"
          Response        = $existing[0]
        }
      }

      try {
        $body = $desired | ConvertTo-Json -Depth 5
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $updateUri" -Tag 'RestCall'
        $response = Invoke-RestMethod -Uri $updateUri -Method Post -Headers $headers -ContentType 'application/json' -Body $body -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $updateUri" -Tag 'RestCall'
      } catch {
        $errorMessage = "Failed to update BuildMaster application '$Name'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      } finally {
      }

      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $true
        Action          = 'Updated'
        ApplicationName = $Name
        ApplicationId   = $response.id
        ResponseSummary = "updated application '$Name'"
        Response        = $response
      }
    }

    $target = "BuildMaster application '$Name'"
    if (-not $PSCmdlet.ShouldProcess($target, 'Create')) {
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $false
        Action          = 'WhatIf'
        ApplicationName = $Name
        ApplicationId   = $null
        ResponseSummary = "WhatIf: planned create of $target"
        Response        = $null
      }
    }

    try {
      $body = $desired | ConvertTo-Json -Depth 5
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $createUri" -Tag 'RestCall'
      $response = Invoke-RestMethod -Uri $createUri -Method Post -Headers $headers -ContentType 'application/json' -Body $body -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $createUri" -Tag 'RestCall'
    } catch {
      $errorMessage = "Failed to create BuildMaster application '$Name'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    } finally {
    }

    return [PSCustomObject]@{
      OperationName   = $fn
      Succeeded       = $true
      Action          = 'Created'
      ApplicationName = $Name
      ApplicationId   = $response.id
      ResponseSummary = "created application '$Name'"
      Response        = $response
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
