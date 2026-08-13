function Remove-BuildMasterScript {
  <#
  .SYNOPSIS
    Removes a BuildMaster script from the default database raft.
  .DESCRIPTION
    Locates a script raft item by name, type, and optional application scope,
    then deletes it with the Native API Rafts_DeleteRaftItem method. The cmdlet
    always targets the default database raft, Raft_Id 1.

    If the script does not exist, the cmdlet returns a successful no-op.
  .PARAMETER ScriptName
    The script item name to remove.
  .PARAMETER ApplicationName
    Optional application name for application-scoped script storage.
  .PARAMETER RaftItemTypeCode
    BuildMaster raft item type code. Defaults to 6.
  .PARAMETER PurgeHistory
    Purges history for the raft item instead of deleting only the current item.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server. Defaults to $global:settings,
    BUILDMASTER_BASE_URL, then https://utat022:50017.
  .PARAMETER BuildMasterAdminApiKeySecretName
    ATAP secret name for the BuildMaster admin API key (Native API access).
    Resolved via Get-PVal; value read with Get-SecretATAP.
  .OUTPUTS
    PSCustomObject describing the removal result.
  .EXAMPLE
    Remove-BuildMasterScript -ScriptName 'Smoke.otter' -Confirm:$false
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    https://buildmaster.inedo.com/reference/api
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScriptName,

    [string]$ApplicationName,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$RaftItemTypeCode = 6,

    [switch]$PurgeHistory,

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
      param([string]$BaseUrl, [string]$AdminApiKeySecretName)
      $resolvedBaseUrl = $BaseUrl
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl) -and $null -ne $global:settings) {
        $settingsKey = 'BuildMasterBaseUrl'
        if ($null -ne $global:configRootKeys -and $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']) {
          $settingsKey = $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']
        }
        if ($global:settings.ContainsKey($settingsKey)) { $resolvedBaseUrl = [string]$global:settings[$settingsKey] }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process') }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User') }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = 'https://utat022:50017' }

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
      return [PSCustomObject]@{ BaseUrl = $resolvedBaseUrl.TrimEnd('/'); ApiKey = $resolvedApiKey }
    }

    function Resolve-BuildMasterApplicationId {
      param([string]$Name, [string]$NativeApiBaseUrl, [string]$Key)
      if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
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
      if ($match.Count -eq 0) { throw "BuildMaster application '$Name' was not found." }
      return [int]$match[0].Application_Id
    }

    $settings = Resolve-BuildMasterApiSettings -BaseUrl $BuildMasterBaseUrl -AdminApiKeySecretName $BuildMasterAdminApiKeySecretName
    $nativeApiBaseUrl = '{0}/api/json' -f $settings.BaseUrl
  }

  process {
    $applicationId = Resolve-BuildMasterApplicationId -Name $ApplicationName -NativeApiBaseUrl $nativeApiBaseUrl -Key $settings.ApiKey
    $itemsUri = "$nativeApiBaseUrl/Rafts_GetRaftItems"
    $queryBody = @{
      API_Key           = $settings.ApiKey
      Raft_Id           = 1
      RaftItemType_Code = $RaftItemTypeCode
      RaftItem_Name     = $ScriptName
    }
    if ($null -ne $applicationId) { $queryBody['Application_Id'] = [int]$applicationId }

    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $itemsUri" -Tag 'RestCall'
      $items = Invoke-RestMethod -Uri $itemsUri -Method Post -Body $queryBody -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $itemsUri" -Tag 'RestCall'
    } catch {
      $errorMessage = "Failed to query BuildMaster script '$ScriptName'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    } finally {
    }

    $existing = @($items | Where-Object { $_.RaftItem_Name -eq $ScriptName } | Select-Object -First 1)
    if ($existing.Count -eq 0 -or $null -eq $existing[0].RaftItem_Id) {
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $true
        Action          = 'Unchanged'
        ScriptName      = $ScriptName
        RaftId          = 1
        RaftItemId      = $null
        ResponseSummary = "script '$ScriptName' was not found"
      }
    }

    $target = "BuildMaster script '$ScriptName'"
    if (-not $PSCmdlet.ShouldProcess($target, 'Delete from default raft')) {
      return [PSCustomObject]@{
        OperationName   = $fn
        Succeeded       = $false
        Action          = 'WhatIf'
        ScriptName      = $ScriptName
        RaftId          = 1
        RaftItemId      = $existing[0].RaftItem_Id
        ResponseSummary = "WhatIf: planned removal of $target"
      }
    }

    $deleteUri = "$nativeApiBaseUrl/Rafts_DeleteRaftItem"
    $deleteBody = @{
      API_Key                = $settings.ApiKey
      RaftItem_Id            = [int]$existing[0].RaftItem_Id
      PurgeHistory_Indicator = if ($PurgeHistory) { 'Y' } else { 'N' }
    }

    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $deleteUri" -Tag 'RestCall'
      Invoke-RestMethod -Uri $deleteUri -Method Post -Body $deleteBody -ErrorAction Stop | Out-Null
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $deleteUri" -Tag 'RestCall'
    } catch {
      $errorMessage = "Failed to remove BuildMaster script '$ScriptName'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    } finally {
    }

    return [PSCustomObject]@{
      OperationName   = $fn
      Succeeded       = $true
      Action          = 'Removed'
      ScriptName      = $ScriptName
      RaftId          = 1
      RaftItemId      = $existing[0].RaftItem_Id
      ResponseSummary = "removed script '$ScriptName'"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
