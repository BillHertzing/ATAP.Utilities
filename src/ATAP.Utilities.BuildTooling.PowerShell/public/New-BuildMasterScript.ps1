function New-BuildMasterScript {
  <#
  .SYNOPSIS
    Creates or updates a BuildMaster script in the default database raft.
  .DESCRIPTION
    Uploads script content to BuildMaster through the Native API
    Rafts_CreateOrUpdateRaftItem method. Content may be supplied directly with
    -ScriptContent or read from -Path. Existing raft items with the same name,
    type, raft, and optional application scope are updated in place.

    The cmdlet always targets the default database raft, Raft_Id 1.
  .PARAMETER ScriptName
    The script item name to store in BuildMaster, such as Build.otter.
  .PARAMETER ScriptContent
    Literal script text to upload.
  .PARAMETER Path
    File path whose content should be uploaded.
  .PARAMETER ApplicationName
    Optional application name for application-scoped script storage. Omit for a
    global/default-raft script.
  .PARAMETER RaftItemTypeCode
    BuildMaster raft item type code. Defaults to 6, the deployment script type
    used by existing BuildMaster plan synchronization.
  .PARAMETER ModifiedByUserName
    User name stamped on the raft item.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server. Defaults to $global:settings,
    BUILDMASTER_BASE_URL, then http://localhost:8622.
  .PARAMETER ApiKey
    BuildMaster API key with Native API access.
  .OUTPUTS
    PSCustomObject describing the uploaded script.
  .EXAMPLE
    New-BuildMasterScript -ScriptName 'CSharpPackage-5Stage.otter' `
      -Path '.\src\ATAP.Utilities.BuildTooling.BuildMaster\Plans\CSharpPackage-5Stage.otter'
  .EXAMPLE
    New-BuildMasterScript -ScriptName 'Smoke.otter' -ScriptContent 'Log-Information ok;'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    https://buildmaster.inedo.com/reference/api
  #>
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Content')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScriptName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Content')]
    [ValidateNotNull()]
    [string]$ScriptContent,

    [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [string]$ApplicationName,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$RaftItemTypeCode = 6,

    [ValidateNotNullOrEmpty()]
    [string]$ModifiedByUserName = $(if ($env:USERNAME) { $env:USERNAME } else { 'API' }),

    [string]$BuildMasterBaseUrl,

    [string]$ApiKey
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    function Resolve-BuildMasterApiSettings {
      param([string]$BaseUrl, [string]$Key)

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

      return [PSCustomObject]@{ BaseUrl = $resolvedBaseUrl.TrimEnd('/'); ApiKey = $resolvedApiKey }
    }

    function Resolve-BuildMasterApplicationId {
      param([string]$Name, [string]$NativeApiBaseUrl, [string]$Key)

      if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
      }

      $applicationsUri = "$NativeApiBaseUrl/Applications_GetApplications"
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $applicationsUri" -Tag 'RestCall'
        $applications = Invoke-RestMethod -Uri $applicationsUri -Method Post -Body @{ API_Key = $Key } -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $applicationsUri" -Tag 'RestCall'
      } catch {
        $errorMessage = "Failed to resolve BuildMaster application '$Name'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      } finally {
      }

      $match = @($applications | Where-Object { $_.Application_Name -eq $Name } | Select-Object -First 1)
      if ($match.Count -eq 0) {
        $match = @($applications | Where-Object { ([string]$_.Application_Name).Equals($Name, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
      }
      if ($match.Count -eq 0) {
        throw "BuildMaster application '$Name' was not found."
      }
      return [int]$match[0].Application_Id
    }

    function Get-BuildMasterRaftItemId {
      param(
        [string]$ItemName,
        [int]$TypeCode,
        [Nullable[int]]$ApplicationId,
        [string]$NativeApiBaseUrl,
        [string]$Key
      )

      $itemsUri = "$NativeApiBaseUrl/Rafts_GetRaftItems"
      $body = @{
        API_Key           = $Key
        Raft_Id           = 1
        RaftItemType_Code = $TypeCode
        RaftItem_Name     = $ItemName
      }
      if ($null -ne $ApplicationId) {
        $body['Application_Id'] = [int]$ApplicationId
      }

      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $itemsUri" -Tag 'RestCall'
        $items = Invoke-RestMethod -Uri $itemsUri -Method Post -Body $body -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $itemsUri" -Tag 'RestCall'
      } catch {
        $errorMessage = "Failed to query BuildMaster raft item '$ItemName'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      } finally {
      }

      $existing = @($items | Where-Object { $_.RaftItem_Name -eq $ItemName } | Select-Object -First 1)
      if ($existing.Count -eq 0 -or $null -eq $existing[0].RaftItem_Id) {
        return $null
      }
      return [int]$existing[0].RaftItem_Id
    }

    $settings = Resolve-BuildMasterApiSettings -BaseUrl $BuildMasterBaseUrl -Key $ApiKey
    $nativeApiBaseUrl = '{0}/api/json' -f $settings.BaseUrl
  }

  process {
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
      try {
        $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        $ScriptContent = Get-Content -LiteralPath $resolvedPath.ProviderPath -Raw -ErrorAction Stop
      } catch {
        $errorMessage = "Failed to read BuildMaster script file '$Path'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      } finally {
      }
    }

    $applicationId = Resolve-BuildMasterApplicationId -Name $ApplicationName -NativeApiBaseUrl $nativeApiBaseUrl -Key $settings.ApiKey
    $raftItemId = Get-BuildMasterRaftItemId -ItemName $ScriptName -TypeCode $RaftItemTypeCode -ApplicationId $applicationId -NativeApiBaseUrl $nativeApiBaseUrl -Key $settings.ApiKey
    $uploadUri = "$nativeApiBaseUrl/Rafts_CreateOrUpdateRaftItem"
    $contentBytes = [System.Text.Encoding]::UTF8.GetBytes($ScriptContent)
    $body = @{
      API_Key              = $settings.ApiKey
      Raft_Id              = 1
      RaftItemType_Code    = $RaftItemTypeCode
      RaftItem_Name        = $ScriptName
      ModifiedOn_Date      = (Get-Date).ToString('o')
      ModifiedBy_User_Name = $ModifiedByUserName
      Content_Bytes        = [Convert]::ToBase64String($contentBytes)
    }
    if ($null -ne $applicationId) {
      $body['Application_Id'] = [int]$applicationId
    }
    if ($null -ne $raftItemId) {
      $body['RaftItem_Id'] = [int]$raftItemId
    }

    if (-not $PSCmdlet.ShouldProcess($ScriptName, 'Create or update BuildMaster script in default raft')) {
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $false
        Action          = 'WhatIf'
        ScriptName      = $ScriptName
        RaftId          = 1
        RaftItemId      = $raftItemId
        ResponseSummary = "WhatIf: planned script upload for '$ScriptName'"
      }
    }

    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $uploadUri" -Tag 'RestCall'
      $response = Invoke-RestMethod -Uri $uploadUri -Method Post -Body $body -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $uploadUri" -Tag 'RestCall'
    } catch {
      $errorMessage = "Failed to create or update BuildMaster script '$ScriptName'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    } finally {
    }

    return [PSCustomObject]@{
      OperationName   = $fn
      Succeeded       = $true
      Action          = if ($null -eq $raftItemId) { 'Created' } else { 'Updated' }
      ScriptName      = $ScriptName
      RaftId          = 1
      RaftItemId      = if ($null -ne $response.RaftItem_Id) { $response.RaftItem_Id } elseif ($null -ne $response) { $response } else { $raftItemId }
      ApplicationId   = $applicationId
      ResponseSummary = "stored script '$ScriptName' in default raft"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
