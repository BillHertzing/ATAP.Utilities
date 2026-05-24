function Sync-BuildMasterPlans {
  <#
  .SYNOPSIS
    Synchronizes local OtterScript plan files into BuildMaster.
  .DESCRIPTION
    Reads .otter files from a local file or directory and uploads them to the
    BuildMaster Native API as raft items. This supports keeping OtterScript
    plans in source control while still publishing the current version into
    BuildMaster for execution.

    The cmdlet uses BUILDMASTER_ADMIN_API_KEY from User scope by default. An
    explicit -ApiKey value may be supplied for tests or controlled automation.

    BuildMaster stores scripts and plans in rafts. The default raft item type
    is DeploymentScript (6), which is appropriate for .otter deployment plans.
    Use -RaftItemTypeCode to target a different BuildMaster script type.
  .PARAMETER Path
    A local .otter file or a directory containing .otter files. When omitted,
    the cmdlet uses BuildMaster.PlansDirectory from $global:settings when that
    ConfigRootKey is available.
  .PARAMETER Recurse
    Recursively include .otter files under a directory path.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server. Defaults to BuildMaster.BaseUrl from
    $global:settings, then BUILDMASTER_BASE_URL from the process environment,
    then http://localhost:50017.
  .PARAMETER ApiKey
    BuildMaster Native API key. Defaults to BUILDMASTER_ADMIN_API_KEY from User
    scope, then Process scope.
  .PARAMETER RaftId
    Target BuildMaster raft id. Defaults to 1, the default database raft.
  .PARAMETER RaftItemTypeCode
    Target BuildMaster raft item type code. Defaults to 6 (DeploymentScript).
  .PARAMETER ApplicationId
    Optional BuildMaster application id for application-scoped plans.
  .PARAMETER ApplicationName
    Optional BuildMaster application name. When supplied, the cmdlet resolves
    ApplicationId with Applications_GetApplications before uploading.
  .PARAMETER ModifiedByUserName
    User name stamped on the uploaded raft item. Defaults to $env:USERNAME, then
    API.
  .PARAMETER PreserveDirectoryStructure
    Preserve relative subdirectory names in the BuildMaster raft item name.
  .PARAMETER SkipExistingLookup
    Skip the pre-upload lookup for an existing raft item id.
  .OUTPUTS
    PSCustomObject describing uploaded files and errors.
  .EXAMPLE
    Sync-BuildMasterPlans -Path .\BuildMasterPlans -ApplicationName 'ATAP.Utilities'
  .EXAMPLE
    Sync-BuildMasterPlans -Path .\Build.otter -BuildMasterBaseUrl 'http://localhost:50017' -WhatIf
  .LINK
    https://docs.inedo.com/docs/buildmaster/reference/api/native
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Position = 0)]
    [string]$Path,

    [switch]$Recurse,

    [string]$BuildMasterBaseUrl,

    [string]$ApiKey,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$RaftId = 1,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$RaftItemTypeCode = 6,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$ApplicationId,

    [string]$ApplicationName,

    [ValidateNotNullOrEmpty()]
    [string]$ModifiedByUserName = $(if ($env:USERNAME) { $env:USERNAME } else { 'API' }),

    [switch]$PreserveDirectoryStructure,

    [switch]$SkipExistingLookup
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Load Helpers
    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
    } catch {
      $errorMessage = "Failed to load Get-ParameterValueFromNeoConfigurationRoot function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    if ([string]::IsNullOrWhiteSpace($Path) -and $global:configRootKeys -and $global:settings) {
      $plansDirectoryKey = $global:configRootKeys['BuildMasterPlansDirectoryConfigRootKey']
      if ($plansDirectoryKey -and $global:settings.ContainsKey($plansDirectoryKey)) {
        $Path = $global:settings[$plansDirectoryKey]
      }
    }
    if ([string]::IsNullOrWhiteSpace($Path)) {
      throw 'Path was not supplied and BuildMaster.PlansDirectory was not found in $global:settings.'
    }

    $BuildMasterBaseUrl = Get-PVal -ParameterName 'BuildMasterBaseUrl' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterBaseUrl

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
      $ApiKey = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'User')
    }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
      $ApiKey = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
      try {
        $ApiKey = Get-BitwardenSecret -SecretName 'BuildMaster_Admin_API_Key' -AsPlainText -ErrorAction SilentlyContinue
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Bitwarden lookup failed (not critical): $($_.Exception.Message)"
      }
    }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
      throw 'BUILDMASTER_ADMIN_API_KEY is not set at User/Process scope or in Bitwarden (secret: BuildMaster_Admin_API_Key). Cannot sync BuildMaster plans.'
    }

    $BuildMasterBaseUrl = $BuildMasterBaseUrl.TrimEnd('/')
    $nativeApiBaseUrl = "$BuildMasterBaseUrl/api/json"

    function Resolve-BuildMasterApplicationId {
      param(
        [Parameter(Mandatory)]
        [string]$Name
      )

      $applicationsUri = "$nativeApiBaseUrl/Applications_GetApplications"
      $applications = Invoke-RestMethod -Uri $applicationsUri -Method Post -Body @{ API_Key = $ApiKey } -ErrorAction Stop
      $match = @($applications | Where-Object { $_.Application_Name -eq $Name })

      if ($match.Count -eq 0) {
        $match = @($applications | Where-Object { $_.Application_Name -ieq $Name })
      }
      if ($match.Count -eq 0) {
        throw "BuildMaster application '$Name' was not found."
      }
      if ($match.Count -gt 1) {
        throw "BuildMaster application name '$Name' matched multiple applications."
      }

      return [int]$match[0].Application_Id
    }

    function Get-BuildMasterRaftItemId {
      param(
        [Parameter(Mandatory)]
        [string]$RaftItemName,

        [int]$ResolvedApplicationId
      )

      $body = @{
        API_Key           = $ApiKey
        Raft_Id           = $RaftId
        RaftItemType_Code = $RaftItemTypeCode
        RaftItem_Name     = $RaftItemName
      }

      if ($ResolvedApplicationId -gt 0) {
        $body['Application_Id'] = $ResolvedApplicationId
      }

      $itemsUri = "$nativeApiBaseUrl/Rafts_GetRaftItems"
      $items = Invoke-RestMethod -Uri $itemsUri -Method Post -Body $body -ErrorAction Stop
      $existing = @($items | Where-Object { $_.RaftItem_Name -eq $RaftItemName } | Select-Object -First 1)

      if ($existing.Count -eq 0 -or $null -eq $existing[0].RaftItem_Id) {
        return $null
      }

      return [int]$existing[0].RaftItem_Id
    }

    function Get-RelativeRaftItemName {
      param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory)]
        [string]$RootPath
      )

      if (-not $PreserveDirectoryStructure) {
        return $File.Name
      }

      $relativePath = [System.IO.Path]::GetRelativePath($RootPath, $File.FullName)
      return ($relativePath -replace '\\', '/')
    }
  }

  process {
    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    $item = Get-Item -LiteralPath $resolvedPath.ProviderPath -ErrorAction Stop

    if ($item.PSIsContainer) {
      $rootPath = $item.FullName
      $files = @(Get-ChildItem -LiteralPath $item.FullName -Filter '*.otter' -File -Recurse:$Recurse -ErrorAction Stop)
    } else {
      if ($item.Extension -ne '.otter') {
        throw "Path '$($item.FullName)' is not an .otter file."
      }
      $rootPath = Split-Path -Parent $item.FullName
      $files = @($item)
    }

    if ($files.Count -eq 0) {
      throw "No .otter files found under '$($item.FullName)'."
    }

    $resolvedApplicationId = $ApplicationId
    if (-not $PSBoundParameters.ContainsKey('ApplicationId') -and -not [string]::IsNullOrWhiteSpace($ApplicationName)) {
      $resolvedApplicationId = Resolve-BuildMasterApplicationId -Name $ApplicationName
    }

    $uploaded = [System.Collections.ArrayList]::new()
    $errors = [System.Collections.ArrayList]::new()
    $uploadUri = "$nativeApiBaseUrl/Rafts_CreateOrUpdateRaftItem"

    foreach ($file in $files) {
      $raftItemName = Get-RelativeRaftItemName -File $file -RootPath $rootPath

      try {
        $contentBytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $body = @{
          API_Key              = $ApiKey
          Raft_Id              = $RaftId
          RaftItemType_Code    = $RaftItemTypeCode
          RaftItem_Name        = $raftItemName
          ModifiedOn_Date      = (Get-Date).ToString('o')
          ModifiedBy_User_Name = $ModifiedByUserName
          Content_Bytes        = [System.Convert]::ToBase64String($contentBytes)
        }

        if ($resolvedApplicationId -gt 0) {
          $body['Application_Id'] = $resolvedApplicationId
        }

        if (-not $SkipExistingLookup) {
          $existingRaftItemId = Get-BuildMasterRaftItemId -RaftItemName $raftItemName -ResolvedApplicationId $resolvedApplicationId
          if ($null -ne $existingRaftItemId) {
            $body['RaftItem_Id'] = $existingRaftItemId
          }
        }

        if ($PSCmdlet.ShouldProcess($raftItemName, "Upload OtterScript plan to BuildMaster raft $RaftId")) {
          Invoke-RestMethod -Uri $uploadUri -Method Post -Body $body -ErrorAction Stop | Out-Null
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Uploaded BuildMaster plan '$raftItemName'"
        }

        [void]$uploaded.Add([PSCustomObject]@{
            Name             = $raftItemName
            Path             = $file.FullName
            RaftId           = $RaftId
            RaftItemTypeCode = $RaftItemTypeCode
            ApplicationId    = if ($resolvedApplicationId -gt 0) { $resolvedApplicationId } else { $null }
            Uploaded         = -not $WhatIfPreference
          })
      } catch {
        $errMsg = "Failed to sync BuildMaster plan '$raftItemName'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
        [void]$errors.Add($errMsg)
      }
    }

    return [PSCustomObject]@{
      PlansSynced = $uploaded.ToArray()
      Errors      = $errors.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
