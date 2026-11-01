function Sync-BuildMasterPlans {
  <#
  .SYNOPSIS
    Synchronizes local OtterScript plan files into BuildMaster.
  .DESCRIPTION
    Reads .otter files from a local file or directory and uploads them to the
    BuildMaster Native API as raft items. This supports keeping OtterScript
    plans in source control while still publishing the current version into
    BuildMaster for execution.

    The API key secret name is resolved via Get-PVal
    (-BuildMasterAdminApiKeySecretName, then env var, then $global:settings,
    then default 'BuildMaster.Admin.API.Key.utat01'); the key value is then retrieved
    through Get-SecretATAP.

    BuildMaster stores scripts and plans in rafts. The default raft item type
    is DeploymentScript (6), which is appropriate for .otter deployment plans.
    Use -RaftItemTypeCode to target a different BuildMaster script type.

    PIPELINES (Task 15.196.r / SC-0444). Pipelines are raft items too, of type 8,
    with a JSON body and a name WITHOUT extension. A plan syncing without its
    pipeline is exactly what left DatabaseChangePackage-5Stage executable on
    utat022 and unreachable on utat01 (defect D7). With -IncludePipelines the
    cmdlet also uploads every '<Name>.pipeline.json' beside the plans as raft
    item '<Name>' of type 8, after verifying the file parses as JSON and its
    'Name' property equals '<Name>' - a mismatch fails closed, because a
    pipeline stored under one name whose body declares another is unusable.
    Every ATAP pipeline is global and raft-stored by decision (2026-09-17); an
    application-scoped pipeline cannot be carried by this cmdlet at all.
  .PARAMETER Path
    A local .otter file or a directory containing .otter files. When omitted,
    the cmdlet uses BuildMaster.PlansDirectory from $global:settings when that
    ConfigRootKey is available. A single '*.pipeline.json' file is accepted
    when -IncludePipelines is set.
  .PARAMETER Recurse
    Recursively include .otter files under a directory path.
  .PARAMETER IncludePipelines
    Also sync '*.pipeline.json' files as type-8 pipeline raft items. Ignored for
    application-scoped uploads (-ApplicationId / -ApplicationName), which fail
    closed for pipelines.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server. Defaults to BuildMaster.BaseUrl from
    $global:settings, then BUILDMASTER_BASE_URL from the process environment,
    then https://utat022:50017.
  .PARAMETER BuildMasterAdminApiKeySecretName
    ATAP secret name for the BuildMaster admin (Native API) key. Resolved via
    Get-PVal; value read with Get-SecretATAP.
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
  .PARAMETER RequireExisting
    Opt-in single literal .otter file update. Requires ExpectedRemoteSha256, a unique
    existing item with a positive integer ID and exact old bytes. Never permits creation.
  .PARAMETER ExpectedRemoteSha256
    Expected SHA-256 of the raw existing item bytes. Paired with RequireExisting.
    The client-side check is not atomic compare-and-swap. A real update is followed by
    a same-ID/new-byte verification; failures are not retried or compensated.
  .OUTPUTS
    PSCustomObject describing uploaded files and errors. Guarded calls additionally return
    GuardedResults and GuardedSuccess; inspect these even when Errors is empty. WhatIf is
    NotWritten, never a verified update. Shared global items affect all their consumers.
  .EXAMPLE
    Sync-BuildMasterPlans -Path .\BuildMasterPlans -ApplicationName 'ATAP.Utilities'
  .EXAMPLE
    Sync-BuildMasterPlans -Path .\Build.otter -BuildMasterBaseUrl 'https://utat022:50017' -WhatIf
  .LINK
    https://docs.inedo.com/docs/buildmaster/reference/api/native
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Position = 0)]
    [string]$Path,

    [switch]$Recurse,

    [string]$BuildMasterBaseUrl,

    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key',

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

    [switch]$SkipExistingLookup,

    [switch]$IncludePipelines,

    [switch]$RequireExisting,

    [ValidatePattern('\A[0-9A-Fa-f]{64}\z')]
    [string]$ExpectedRemoteSha256
  )

  begin {
    # Validate the opt-in shape before logging, settings resolution, secrets or API calls.
    $guarded = $PSBoundParameters.ContainsKey('RequireExisting') -or $PSBoundParameters.ContainsKey('ExpectedRemoteSha256')
    if ($guarded) {
      if (-not $RequireExisting -or -not $PSBoundParameters.ContainsKey('ExpectedRemoteSha256')) { throw 'GuardedParametersMustBePaired' }
      if (-not $PSBoundParameters.ContainsKey('Path') -or [string]::IsNullOrWhiteSpace($Path) -or
          [Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Path) -or
          $PSBoundParameters.ContainsKey('Recurse') -or $PSBoundParameters.ContainsKey('IncludePipelines') -or
          $PSBoundParameters.ContainsKey('SkipExistingLookup')) { throw 'GuardedSingleLiteralFileRequired' }
      if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or [IO.Path]::GetExtension($Path) -ine '.otter') { throw 'GuardedSingleLiteralFileRequired' }
    }
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

    if ([string]::IsNullOrWhiteSpace($Path) -and $global:configRootKeys -and $global:settings) {
      $plansDirectoryKey = $global:configRootKeys['BuildMasterPlansDirectoryConfigRootKey']
      if ($plansDirectoryKey -and $global:settings.ContainsKey($plansDirectoryKey)) {
        $Path = $global:settings[$plansDirectoryKey]
      }
    }
    if ([string]::IsNullOrWhiteSpace($Path)) {
      throw 'Path was not supplied and BuildMaster.PlansDirectory was not found in $global:settings.'
    }

    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl) -and $global:configRootKeys -and $global:settings) {
      $baseUrlKey = $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']
      if ($baseUrlKey -and $global:settings.ContainsKey($baseUrlKey)) {
        $BuildMasterBaseUrl = [string]$global:settings[$baseUrlKey]
      }
    }
    $BuildMasterBaseUrl = Get-PVal -ParameterName 'BuildMasterBaseUrl' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterBaseUrl
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $BuildMasterBaseUrl = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $BuildMasterBaseUrl = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User')
    }
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $BuildMasterBaseUrl = 'https://utat022:50017'
    }

    $BuildMasterAdminApiKeySecretName = Get-PVal -ParameterName 'BuildMasterAdminApiKeySecretName' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterAdminApiKeySecretName
    # Retrieve the BuildMaster admin API key value via Get-SecretATAP using the
    # resolved secret name. The key value is never logged.
    $ApiKey = $null
    $secretErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($fieldName in @($null, 'token', 'key', 'password')) {
      try {
        $candidate = if ($null -eq $fieldName) {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
        } else {
          Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -SecretField $fieldName -ErrorAction Stop
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { $ApiKey = [string]$candidate; break }
      } catch {
        $fieldLabel = if ($null -eq $fieldName) { '<default>' } else { $fieldName }
        $secretErrors.Add("${fieldLabel}: $($_.Exception.Message)") | Out-Null
      }
    }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
      $detail = if ($secretErrors.Count -gt 0) { " Last error: $($secretErrors[$secretErrors.Count - 1])" } else { '' }
      throw "Unable to resolve the BuildMaster admin API key value from secret '$BuildMasterAdminApiKeySecretName' via Get-SecretATAP. Cannot sync BuildMaster plans.$detail"
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

        [int]$ResolvedApplicationId,

        [int]$ItemTypeCode = $RaftItemTypeCode,

        [string]$RequiredSha256 = $ExpectedRemoteSha256
      )

      $body = @{
        API_Key           = $ApiKey
        Raft_Id           = $RaftId
        RaftItemType_Code = $ItemTypeCode
        RaftItem_Name     = $RaftItemName
      }

      if ($ResolvedApplicationId -gt 0) {
        $body['Application_Id'] = $ResolvedApplicationId
      }

      $itemsUri = "$nativeApiBaseUrl/Rafts_GetRaftItems"
      $items = Invoke-RestMethod -Uri $itemsUri -Method Post -Body $body -ErrorAction Stop
      if ($guarded) {
        # Count all case-insensitive matches, then require the exact intended spelling.
        # Never hide ambiguity with the legacy first-match selection below.
        $guardedMatches = @($items | Where-Object { $_ -and $_.PSObject.Properties['RaftItem_Name'] -and $_.RaftItem_Name -ieq $RaftItemName })
        if ($guardedMatches.Count -ne 1) { throw 'GuardedExistingNotUnique' }
        $existing = $guardedMatches[0]
        if ([string]$existing.RaftItem_Name -cne $RaftItemName) { throw 'GuardedExistingNameMismatch' }
        $idProperty = $existing.PSObject.Properties['RaftItem_Id']
        $rawId = if ($idProperty) { $idProperty.Value } else { $null }
        $integerType = $rawId -is [byte] -or $rawId -is [sbyte] -or $rawId -is [int16] -or $rawId -is [uint16] -or
          $rawId -is [int] -or $rawId -is [uint32] -or $rawId -is [long] -or $rawId -is [ulong]
        $validatedId = 0
        if (($rawId -isnot [string] -and -not $integerType) -or [string]$rawId -notmatch '\A[0-9]+\z' -or
            -not [int]::TryParse([string]$rawId, [Globalization.NumberStyles]::None, [Globalization.CultureInfo]::InvariantCulture, [ref]$validatedId) -or
            $validatedId -le 0) { throw 'GuardedExistingIdInvalid' }
        $remoteBytes = $null
        foreach ($propertyName in @('Content_Bytes', 'Content_Text', 'Content')) {
          $property = $existing.PSObject.Properties[$propertyName]
          if (-not $property -or $null -eq $property.Value) { continue }
          if ($property.Value -is [byte[]]) { $remoteBytes = $property.Value; break }
          if ($property.Value -isnot [string]) { throw 'GuardedExistingContentInvalid' }
          $text = [string]$property.Value
          if ($text.Length -eq 0) { continue }
          if ($propertyName -ceq 'Content_Bytes') {
            try { $remoteBytes = [Convert]::FromBase64String($text) }
            catch { $remoteBytes = [Text.Encoding]::UTF8.GetBytes($text) }
          } else { $remoteBytes = [Text.Encoding]::UTF8.GetBytes($text) }
          break
        }
        if ($null -eq $remoteBytes -or $remoteBytes.Length -eq 0) { throw 'GuardedExistingContentInvalid' }
        $remoteSha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$remoteBytes))
        if ($remoteSha -ine $RequiredSha256) { throw 'GuardedRemoteHashMismatch' }
        return $validatedId
      }
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

    # Pipeline raft items (type 8) are named WITHOUT extension and carry a JSON body
    # whose 'Name' must equal the raft item name. Fail closed on either violation:
    # a pipeline stored under a name its body does not declare is unusable and, worse,
    # looks synced.
    $pipelineFileSuffix = '.pipeline.json'
    $pipelineRaftItemTypeCode = 8

    function Test-PipelineFile {
      param([Parameter(Mandatory)][System.IO.FileInfo]$File)
      return $File.Name.EndsWith($pipelineFileSuffix, [System.StringComparison]::OrdinalIgnoreCase)
    }

    function Get-PipelineRaftItemName {
      param([Parameter(Mandatory)][System.IO.FileInfo]$File)

      $itemName = $File.Name.Substring(0, $File.Name.Length - $pipelineFileSuffix.Length)
      if ([string]::IsNullOrWhiteSpace($itemName)) {
        throw "Pipeline file '$($File.FullName)' has no name before '$pipelineFileSuffix'."
      }

      try {
        $document = Get-Content -LiteralPath $File.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -Depth 32 -ErrorAction Stop
      } catch {
        throw "Pipeline file '$($File.FullName)' is not valid JSON: $($_.Exception.Message)"
      }
      $declaredName = if ($document.PSObject.Properties['Name']) { [string]$document.Name } else { '' }
      if ($declaredName -cne $itemName) {
        throw "Pipeline file '$($File.Name)' declares Name '$declaredName'; the raft item name derived from the file name is '$itemName'. They must match exactly."
      }
      if (-not $document.PSObject.Properties['Stages'] -or @($document.Stages).Count -eq 0) {
        throw "Pipeline file '$($File.Name)' declares no Stages."
      }

      return $itemName
    }
  }

  process {
    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    $item = Get-Item -LiteralPath $resolvedPath.ProviderPath -ErrorAction Stop

    if ($item.PSIsContainer) {
      $rootPath = $item.FullName
      $files = @(Get-ChildItem -LiteralPath $item.FullName -Filter '*.otter' -File -Recurse:$Recurse -ErrorAction Stop)
      if ($IncludePipelines) {
        $files += @(Get-ChildItem -LiteralPath $item.FullName -Filter "*$pipelineFileSuffix" -File -Recurse:$Recurse -ErrorAction Stop)
      }
    } else {
      $isPipelineFile = (Test-PipelineFile -File $item)
      if ($item.Extension -ne '.otter' -and -not ($IncludePipelines -and $isPipelineFile)) {
        throw "Path '$($item.FullName)' is not an .otter file$(if ($IncludePipelines) { " or a *$pipelineFileSuffix file" })."
      }
      $rootPath = Split-Path -Parent $item.FullName
      $files = @($item)
    }

    if ($files.Count -eq 0) {
      throw "No .otter$(if ($IncludePipelines) { " or *$pipelineFileSuffix" }) files found under '$($item.FullName)'."
    }

    $resolvedApplicationId = $ApplicationId
    if (-not $PSBoundParameters.ContainsKey('ApplicationId') -and -not [string]::IsNullOrWhiteSpace($ApplicationName)) {
      $resolvedApplicationId = Resolve-BuildMasterApplicationId -Name $ApplicationName
    }

    $uploaded = [System.Collections.ArrayList]::new()
    $errors = [System.Collections.ArrayList]::new()
    $guardedResults = [System.Collections.ArrayList]::new()
    $uploadUri = "$nativeApiBaseUrl/Rafts_CreateOrUpdateRaftItem"

    foreach ($file in $files) {
      $isPipeline = (Test-PipelineFile -File $file)
      $raftItemName = $null
      $guardResult = $null
      if ($guarded) {
        $guardResult = [pscustomobject]@{ Name = $file.Name; Status = 'NotWritten'; ExistingRaftItemId = $null
          ExpectedRemoteSha256 = $ExpectedRemoteSha256; IntendedSha256 = $null; WriteAttempted = $false; WriteCompleted = $false; PostReadVerified = $false }
        [void]$guardedResults.Add($guardResult)
      }

      try {
        if ($isPipeline) {
          if ($resolvedApplicationId -gt 0) {
            throw 'Pipelines are global by decision (Task 15.196.r); an application-scoped pipeline upload is refused.'
          }
          $raftItemName = Get-PipelineRaftItemName -File $file
          $itemTypeCode = $pipelineRaftItemTypeCode
          $itemKind = 'pipeline'
        } else {
          $raftItemName = Get-RelativeRaftItemName -File $file -RootPath $rootPath
          $itemTypeCode = $RaftItemTypeCode
          $itemKind = 'OtterScript plan'
        }

        $contentBytes = [System.IO.File]::ReadAllBytes($file.FullName)
        if ($guarded) { $guardResult.IntendedSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$contentBytes)) }
        $body = @{
          API_Key              = $ApiKey
          Raft_Id              = $RaftId
          RaftItemType_Code    = $itemTypeCode
          RaftItem_Name        = $raftItemName
          ModifiedOn_Date      = (Get-Date).ToString('o')
          ModifiedBy_User_Name = $ModifiedByUserName
          Content_Bytes        = [System.Convert]::ToBase64String($contentBytes)
        }

        if ($resolvedApplicationId -gt 0) {
          $body['Application_Id'] = $resolvedApplicationId
        }

        if (-not $SkipExistingLookup) {
          $existingRaftItemId = Get-BuildMasterRaftItemId -RaftItemName $raftItemName -ResolvedApplicationId $resolvedApplicationId -ItemTypeCode $itemTypeCode
          if ($null -ne $existingRaftItemId) {
            $body['RaftItem_Id'] = $existingRaftItemId
            if ($guarded) { $guardResult.ExistingRaftItemId = $existingRaftItemId }
          }
        }

        if ($PSCmdlet.ShouldProcess($raftItemName, "Upload $itemKind to BuildMaster raft $RaftId (type $itemTypeCode)")) {
          if ($guarded) { $guardResult.WriteAttempted = $true; $guardResult.Status = 'WriteUnverified' }
          Invoke-RestMethod -Uri $uploadUri -Method Post -Body $body -ErrorAction Stop | Out-Null
          if ($guarded) {
            $guardResult.WriteCompleted = $true; $guardResult.Status = 'PostReadUnverified'
            $postId = Get-BuildMasterRaftItemId -RaftItemName $raftItemName -ResolvedApplicationId $resolvedApplicationId -ItemTypeCode $itemTypeCode -RequiredSha256 $guardResult.IntendedSha256
            if ($postId -ne $existingRaftItemId) { throw 'GuardedPostReadIdMismatch' }
            $guardResult.PostReadVerified = $true; $guardResult.Status = 'Verified'
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Uploaded BuildMaster $itemKind '$raftItemName'"
        }

        [void]$uploaded.Add([PSCustomObject]@{
            Name             = $raftItemName
            Path             = $file.FullName
            RaftId           = $RaftId
            RaftItemTypeCode = $itemTypeCode
            ApplicationId    = if ($resolvedApplicationId -gt 0) { $resolvedApplicationId } else { $null }
            Uploaded         = $(if ($guarded) { $guardResult.WriteCompleted } else { -not $WhatIfPreference })
          })
      } catch {
        if ($guarded -and -not $guardResult.WriteAttempted) { $guardResult.Status = 'RefusedBeforeWrite' }
        if ([string]::IsNullOrWhiteSpace($raftItemName)) { $raftItemName = $file.Name }
        $errMsg = "Failed to sync BuildMaster plan '$raftItemName'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
        [void]$errors.Add($errMsg)
      }
    }

    $result = [PSCustomObject]@{
      PlansSynced = $uploaded.ToArray()
      Errors      = $errors.ToArray()
    }
    if ($guarded) {
      $result | Add-Member NoteProperty GuardedResults $guardedResults.ToArray()
      $result | Add-Member NoteProperty GuardedSuccess ($guardedResults.Count -eq 1 -and $guardedResults[0].PostReadVerified -and $errors.Count -eq 0)
    }
    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
