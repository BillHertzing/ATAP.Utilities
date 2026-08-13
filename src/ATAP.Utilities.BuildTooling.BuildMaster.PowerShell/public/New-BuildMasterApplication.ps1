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

    The API key secret name is resolved via Get-PVal
    (-BuildMasterAdminApiKeySecretName, then env var, then $global:settings,
    then default 'BuildMaster.Admin.API.Key.utat01'); the key value is then retrieved
    through Get-SecretATAP.
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
    Artifact storage mode. The default sentinel means the field is omitted so
    the server applies its supported default; it is never sent to the API.
  .PARAMETER ArtifactAssetDirectory
    Asset directory secure resource name when ArtifactUsage is AssetDirectory.
  .PARAMETER Raft
    Optional raft name. Defaults to null, which uses BuildMaster's default raft.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server. Defaults to $global:settings,
    BUILDMASTER_BASE_URL, then https://utat022:50017.
  .PARAMETER BuildMasterAdminApiKeySecretName
    ATAP secret name for the BuildMaster admin API key (Application Management
    permission). Resolved via Get-PVal; value read with Get-SecretATAP.
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

    function Resolve-BuildMasterApiSettings {
      param(
        [string]$BaseUrl,
        [string]$AdminApiKeySecretName
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
        $resolvedBaseUrl = 'https://utat022:50017'
      }

      # Retrieve the BuildMaster admin API key value via Get-SecretATAP using
      # the resolved secret name. The key value is never logged.
      $resolvedApiKey = $null
      $secretErrors = [System.Collections.Generic.List[string]]::new()
      foreach ($fieldName in @($null, 'token', 'key', 'password')) {
        try {
          $candidate = if ($null -eq $fieldName) {
            Get-SecretATAP -SecretName $AdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
          } else {
            Get-SecretATAP -SecretName $AdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -SecretField $fieldName -ErrorAction Stop
          }
          if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { $resolvedApiKey = [string]$candidate; break }
        } catch {
          $fieldLabel = if ($null -eq $fieldName) { '<default>' } else { $fieldName }
          $secretErrors.Add("${fieldLabel}: $($_.Exception.Message)") | Out-Null
        }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
        $detail = if ($secretErrors.Count -gt 0) { " Last error: $($secretErrors[$secretErrors.Count - 1])" } else { '' }
        throw "Unable to resolve the BuildMaster admin API key value from secret '$AdminApiKeySecretName' via Get-SecretATAP.$detail"
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
        $existingProperty = $Existing.PSObject.Properties |
          Where-Object { $_.Name.Equals($key, [System.StringComparison]::OrdinalIgnoreCase) } |
          Select-Object -First 1
        if ($null -eq $existingProperty) {
          return $false
        }
        $existingValue = $existingProperty.Value
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

    function Get-BuildMasterApplicationApiErrorDetail {
      param([System.Management.Automation.ErrorRecord]$ErrorRecord)

      $parts = [System.Collections.Generic.List[string]]::new()
      if ($null -ne $ErrorRecord.Exception.Response) {
        $statusCode = $ErrorRecord.Exception.Response.StatusCode
        if ($null -ne $statusCode) {
          $parts.Add("HTTP $([int]$statusCode) $statusCode") | Out-Null
        }
      }
      if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        $detail = $ErrorRecord.ErrorDetails.Message
        if ($detail.Length -gt 2000) { $detail = $detail.Substring(0, 2000) }
        $parts.Add($detail) | Out-Null
      }
      if ($parts.Count -eq 0) {
        $parts.Add($ErrorRecord.Exception.Message) | Out-Null
      }
      return ($parts -join ': ')
    }

    $settings = Resolve-BuildMasterApiSettings -BaseUrl $BuildMasterBaseUrl -AdminApiKeySecretName $BuildMasterAdminApiKeySecretName
    $headers = @{ 'X-ApiKey' = $settings.ApiKey }
    $listUri = '{0}/api/applications/list' -f $settings.BaseUrl
    $createUri = '{0}/api/applications/create' -f $settings.BaseUrl
    $updateUri = '{0}/api/applications/update' -f $settings.BaseUrl
  }

  process {
    if ($ArtifactUsage -eq 'AssetDirectory' -and [string]::IsNullOrWhiteSpace($ArtifactAssetDirectory)) {
      throw 'ArtifactAssetDirectory is required when ArtifactUsage is AssetDirectory.'
    }
    if ($ArtifactUsage -ne 'AssetDirectory' -and -not [string]::IsNullOrWhiteSpace($ArtifactAssetDirectory)) {
      throw 'ArtifactAssetDirectory is valid only when ArtifactUsage is AssetDirectory.'
    }

    $desired = [ordered]@{
      name                   = $Name
      description            = $Description
      active                 = $Active
      buildNumberScheme      = $BuildNumberScheme
      releaseUsage           = $ReleaseUsage
      allowIssues            = $AllowIssues
      displayIssues          = $DisplayIssues
      displayPipelines       = $DisplayPipelines
      displayScripts         = $DisplayScripts
      displayConfiguration   = $DisplayConfiguration
      displayDatabase        = $DisplayDatabase
    }
    if (-not [string]::IsNullOrWhiteSpace($GroupName)) {
      $desired.groupName = $GroupName
    }
    if (-not [string]::IsNullOrWhiteSpace($SetupTemplate)) {
      $desired.setupTemplate = $SetupTemplate
    }
    if (-not [string]::IsNullOrWhiteSpace($DefaultReleaseTemplate)) {
      $desired.defaultReleaseTemplate = $DefaultReleaseTemplate
    }
    if ($PSBoundParameters.ContainsKey('BuildPageDescription')) {
      $desired.buildPageDescription = $BuildPageDescription
    }
    if ($ArtifactUsage -ne 'Default') {
      $desired.artifactUsage = $ArtifactUsage
    }
    if ($ArtifactUsage -eq 'AssetDirectory') {
      $desired.artifactAssetDirectory = $ArtifactAssetDirectory
    }
    if ($PSBoundParameters.ContainsKey('Raft') -and -not [string]::IsNullOrWhiteSpace($Raft)) {
      $desired.raft = $Raft
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
        $detail = Get-BuildMasterApplicationApiErrorDetail -ErrorRecord $_
        $errorMessage = "Failed to update BuildMaster application '$Name'. Validation response: $detail"
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
      $detail = Get-BuildMasterApplicationApiErrorDetail -ErrorRecord $_
      $errorMessage = "Failed to create BuildMaster application '$Name'. Validation response: $detail"
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
