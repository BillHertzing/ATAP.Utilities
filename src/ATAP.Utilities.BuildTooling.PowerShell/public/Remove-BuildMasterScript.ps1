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
    BUILDMASTER_BASE_URL, then http://localhost:50017.
  .PARAMETER ApiKey
    BuildMaster API key with Native API access.
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
        if ($global:settings.ContainsKey($settingsKey)) { $resolvedBaseUrl = [string]$global:settings[$settingsKey] }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process') }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User') }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = 'http://localhost:50017' }

      $resolvedApiKey = $Key
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey) -and $null -ne $global:settings) {
        $settingsKey = 'BuildMasterAdminApiKey'
        if ($null -ne $global:configRootKeys -and $global:configRootKeys['BuildMasterAdminApiKeyConfigRootKey']) {
          $settingsKey = $global:configRootKeys['BuildMasterAdminApiKeyConfigRootKey']
        }
        if ($global:settings.ContainsKey($settingsKey)) { $resolvedApiKey = [string]$global:settings[$settingsKey] }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) { $resolvedApiKey = [Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'Process') }
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) { $resolvedApiKey = [Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'User') }
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) { throw 'Unable to resolve BuildMaster API key. Pass -ApiKey or define BUILDMASTER_ADMIN_API_KEY.' }
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

    $settings = Resolve-BuildMasterApiSettings -BaseUrl $BuildMasterBaseUrl -Key $ApiKey
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
