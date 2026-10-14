function Compare-BuildMasterPlanRaft {
  <#
  .SYNOPSIS
    Compares deployed BuildMaster raft plans against the on-disk OtterScript files, read-only.
  .DESCRIPTION
    BuildMaster executes the copy of an OtterScript plan stored in its raft, not the
    .otter file in the worktree, while the paired stage-runner .ps1 IS read from disk
    at run time. A commit that changes both halves therefore leaves the raft passing the
    OLD argument list to the NEW parameter block, which hangs the stage forever with no
    error. See SolutionDocumentation/BuildMaster-Plan-Raft-Sync-Requirement.md.

    This cmdlet is the detection half of that rule. For each plan it fetches the deployed
    raft item through the Native API (Rafts_GetRaftItems), compares it to the file on
    disk, and cross-checks the plan's Exec 'Arguments:' argument NAMES against the
    paired runner script's parameter names.

    ARGUMENT-ASYMMETRY CLASSIFICATION (Task 15.171.e). A runner parameter the plan does
    not pass is only a defect when that parameter is MANDATORY; then the stage blocks
    forever on an invisible console prompt under BuildMaster's non-interactive LocalAgent,
    which is the 2026-08-03 signature. An OPTIONAL parameter the plan does not pass is
    normal, permanent, and present on every healthy plan - CSharpPackage-5Stage is
    byte-identical to disk with zero mandatory parameters missing and still leaves seven
    optional runner parameters unpassed (unit 15.171.b, raft item 2009). The original
    ArgumentNameDrift reason conflated the two, so every healthy plan reported Drift; a
    gate wired to a permanently red field is ignored within about two runs, which leaves
    the pipeline less protected than before the gate existed. Optional-only asymmetry is
    therefore reported in InformationalReasons and does NOT set Status = Drift, while the
    two genuinely broken shapes get their own reason codes and still do:

      MandatoryArgumentMissing - a MANDATORY runner parameter is absent from the deployed
        raft's Arguments: line. The silent-forever-hang signature. Highest severity, and
        deliberately its own code rather than a shade of a generic one.
      UndeclaredArgument       - the plan passes an argument the runner does not declare.
        The runner errors on the next run: broken, but loudly.

    Detection is not weakened to obtain the green light. Mandatory-ness is read from the
    runner's own param block on disk, and a parameter marked mandatory in ANY parameter
    set counts as mandatory - the conservative reading, because the cmdlet cannot know
    which set a given invocation resolves to and a missed mandatory parameter is the one
    failure this cmdlet exists to catch.

    Mandatory-ness now travels IN THE OUTPUT (MandatoryParameterAnalysis,
    SilentHangSignaturePresent, and the per-runner Mandatory/Optional split) rather than
    being recomputed by every consumer, which is the durable fix recorded as known
    limitation 1 of SolutionDocumentation/BuildMaster-Plan-Raft-Drift-Gate.md. That
    document's severity model reads RunnerParametersNotInPlan, ArgumentsNotInRunner,
    DriftReasons, and ContentMatches; all four keep their previous meaning, so the model
    still computes - it simply no longer has to parse runner scripts itself.

    The cmdlet is strictly read-only. It never calls a BuildMaster write endpoint, has no
    ShouldProcess surface because it never writes, and emits METADATA ONLY - hashes,
    lengths, timestamps, argument names, and a status. It never emits plan bodies, script
    bodies, content diffs, or any secret, so its output is safe to publish as evidence.

    Resolution of the BuildMaster base URL and of the admin API key follows exactly the
    convention used by Sync-BuildMasterPlans: $global:settings ConfigRootKeys, then
    Get-PVal, then the process and user environment, then a default; the secret name is
    host-suffixed through Resolve-HostSuffixedSecretName and the key VALUE is read with
    Get-SecretATAP against the BitwardenSecretsManager store. The key is never logged and
    never emitted.

    A server call that fails for any reason fails CLOSED: the plan is reported as
    Unreachable with the reason, never as Match.
  .PARAMETER Path
    One or more .otter files, or directories containing them. When omitted, the cmdlet
    uses BuildMaster.PlansDirectory from $global:settings when that ConfigRootKey is
    available.
  .PARAMETER Recurse
    Recursively include .otter files under a directory path.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server. Defaults to BuildMaster.BaseUrl from
    $global:settings, then BUILDMASTER_BASE_URL from the process then user environment,
    then https://utat022:50017.
  .PARAMETER BuildMasterAdminApiKeySecretName
    ATAP secret name for the BuildMaster admin (Native API) key. Resolved via Get-PVal
    and host-suffixed via Resolve-HostSuffixedSecretName; value read with Get-SecretATAP.
  .PARAMETER RaftId
    Target BuildMaster raft id. Defaults to 1, the default database raft.
  .PARAMETER RaftItemTypeCode
    Target BuildMaster raft item type code. Defaults to 6 (DeploymentScript).
  .PARAMETER RaftItemName
    Overrides the raft item name that would otherwise be derived from the file name.
    Valid only when exactly one plan is being compared.
  .PARAMETER ApplicationId
    BuildMaster application id for an application-scoped raft item. An unscoped query
    silently omits application-scoped items, so this must be supplied for them - for
    example AceCommander-ApplicationRelease under Application_Id 1003.
  .PARAMETER ApplicationName
    BuildMaster application name. When supplied, ApplicationId is resolved through
    Applications_GetApplications before the raft query.
  .PARAMETER RunnerScriptDirectory
    Directory holding the paired stage-runner .ps1 files. Defaults to the directory
    containing each .otter file.
  .PARAMETER IncludePipelines
    Also compare '<Name>.pipeline.json' files against the type-8 pipeline raft item
    '<Name>' (Task 15.196.r / SC-0444). Pipelines have no runner arguments, so only the
    content comparison applies: ArgumentSource is 'NotApplicable', ArgumentComparison and
    MandatoryParameterAnalysis are empty, and SilentHangSignaturePresent is $false
    (there is no argument list that could hang). Status semantics are unchanged: any byte
    difference is Drift, because a raft pipeline not written from the committed bytes is
    exactly the condition that let DatabaseChangePackage-5Stage exist on one host only.
  .OUTPUTS
    PSCustomObject, one per plan, carrying metadata only. Status is one of Match, Drift,
    MissingFromRaft, MissingOnDisk, or Unreachable.

    DriftReasons holds only conditions that make Status = Drift: ContentDrift,
    WhitespaceOnlyContentDrift, MandatoryArgumentMissing, UndeclaredArgument,
    RunnerScriptMissing, or the terminal status itself. InformationalReasons holds
    benign observations that must NOT turn a plan red - today that is
    OptionalParametersNotPassed.

    SilentHangSignaturePresent is $true when a mandatory runner parameter is missing from
    the raft, $false when the check ran and found none, and $null when the check could not
    run at all (MissingFromRaft, MissingOnDisk, Unreachable, or an unresolvable runner).
    $null is deliberately not $false: a check that did not happen must never read as a
    check that passed.

    MandatoryParameterAnalysis carries, per runner script, MandatoryRunnerParameterCount,
    MandatoryRunnerParametersMissingFromRaft, and SilentHangSignaturePresent.
  .EXAMPLE
    Compare-BuildMasterPlanRaft -Path .\Plans -Recurse

    Compares every global plan in the directory against raft 1.
  .EXAMPLE
    Compare-BuildMasterPlanRaft -Path .\Plans\AceCommander-ApplicationRelease.otter -ApplicationId 1003

    Compares the application-scoped plan. Without the application scope the raft query
    returns only global items and the plan would look as though it did not exist.
  .NOTES
    Read-only by construction: no BuildMaster write endpoint is ever called and no
    ShouldProcess surface is exposed. Emits metadata only - never plan bodies or secrets.
  .LINK
    https://docs.inedo.com/docs/buildmaster/reference/api/native
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('FullName')]
    [string[]]$Path,

    [switch]$Recurse,

    [string]$BuildMasterBaseUrl,

    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key',

    [ValidateRange(1, [int]::MaxValue)]
    [int]$RaftId = 1,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$RaftItemTypeCode = 6,

    [string]$RaftItemName,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$ApplicationId,

    [string]$ApplicationName,

    [string]$RunnerScriptDirectory,

    [switch]$IncludePipelines
  )

  begin {
    # SC-0288 / Task 13.66.b: the SecretName host suffix is derived from the service placement
    # host, never hard-coded. Same resolution shape as Sync-BuildMasterPlans, deliberately -
    # a second convention for the same secret is how the two halves drift apart.
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

    if (($null -eq $Path -or $Path.Count -eq 0) -and $global:configRootKeys -and $global:settings) {
      $plansDirectoryKey = $global:configRootKeys['BuildMasterPlansDirectoryConfigRootKey']
      if ($plansDirectoryKey -and $global:settings.ContainsKey($plansDirectoryKey)) {
        $Path = @([string]$global:settings[$plansDirectoryKey])
      }
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
    # The key VALUE is resolved here and never logged, never emitted, never placed in a
    # status or reason string.
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
      throw "Unable to resolve the BuildMaster admin API key value from secret '$BuildMasterAdminApiKeySecretName' via Get-SecretATAP. Cannot compare BuildMaster plans.$detail"
    }

    $BuildMasterBaseUrl = $BuildMasterBaseUrl.TrimEnd('/')
    $nativeApiBaseUrl = "$BuildMasterBaseUrl/api/json"

    # pwsh host switches that appear on an Exec Arguments: line but are NOT stage-runner
    # parameters. Excluding them is what makes an argument-name comparison meaningful.
    $powerShellHostSwitch = @(
      'NoProfile', 'NonInteractive', 'NoLogo', 'NoExit', 'File', 'Command',
      'EncodedCommand', 'ExecutionPolicy', 'WindowStyle', 'InputFormat', 'OutputFormat', 'Version'
    )

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

    # Pipeline raft items (type 8): named without extension, JSON body. Same naming rule
    # as Sync-BuildMasterPlans so the two halves cannot disagree about what a pipeline is.
    $pipelineFileSuffix = '.pipeline.json'
    $pipelineRaftItemTypeCode = 8

    function Test-PipelineFile {
      param([Parameter(Mandatory)][System.IO.FileInfo]$File)
      return $File.Name.EndsWith($pipelineFileSuffix, [System.StringComparison]::OrdinalIgnoreCase)
    }

    function Get-BuildMasterRaftItem {
      param(
        [Parameter(Mandatory)]
        [string]$ItemName,

        [int]$ResolvedApplicationId,

        [int]$ItemTypeCode = $RaftItemTypeCode
      )

      $body = @{
        API_Key           = $ApiKey
        Raft_Id           = $RaftId
        RaftItemType_Code = $ItemTypeCode
        RaftItem_Name     = $ItemName
      }

      # An unscoped query returns only global items, so an application-scoped plan would
      # look as though it had been deleted. See the sync-requirement doc, 2026-09-04.
      if ($ResolvedApplicationId -gt 0) {
        $body['Application_Id'] = $ResolvedApplicationId
      }

      $itemsUri = "$nativeApiBaseUrl/Rafts_GetRaftItems"
      $items = Invoke-RestMethod -Uri $itemsUri -Method Post -Body $body -ErrorAction Stop
      $existing = @($items | Where-Object { $_.RaftItem_Name -eq $ItemName })
      if ($existing.Count -eq 0) {
        $existing = @($items | Where-Object { $_.RaftItem_Name -ieq $ItemName })
      }
      if ($existing.Count -eq 0) { return $null }

      return $existing[0]
    }

    function ConvertTo-RaftContentByte {
      param([Parameter()]$RaftItem)

      if ($null -eq $RaftItem) { return $null }

      foreach ($propertyName in @('Content_Bytes', 'Content_Text', 'Content')) {
        $value = $RaftItem.PSObject.Properties[$propertyName]
        if ($null -eq $value -or $null -eq $value.Value) { continue }

        $raw = $value.Value
        if ($raw -is [byte[]]) { return $raw }

        $text = [string]$raw
        if ([string]::IsNullOrEmpty($text)) { continue }

        if ($propertyName -eq 'Content_Bytes') {
          try { return [System.Convert]::FromBase64String($text) } catch { return [System.Text.Encoding]::UTF8.GetBytes($text) }
        }
        return [System.Text.Encoding]::UTF8.GetBytes($text)
      }

      return $null
    }

    function Get-Sha256Hex {
      param([byte[]]$Byte)

      if ($null -eq $Byte) { return $null }

      $sha = [System.Security.Cryptography.SHA256]::Create()
      try {
        return -join ($sha.ComputeHash($Byte) | ForEach-Object { $_.ToString('x2') })
      } finally {
        $sha.Dispose()
      }
    }

    function ConvertTo-NormalizedPlanText {
      # Used only to classify a byte difference as whitespace-only. The text is never
      # emitted; only the boolean result of comparing two normalizations leaves here.
      param([byte[]]$Byte)

      if ($null -eq $Byte) { return $null }

      $text = [System.Text.Encoding]::UTF8.GetString($Byte).TrimStart([char]0xFEFF)
      $text = $text -replace "`r`n", "`n"
      $lines = $text -split "`n" | ForEach-Object { $_.TrimEnd() }
      return (($lines -join "`n").TrimEnd())
    }

    function Get-PlanRunnerArgument {
      # Returns, per runner script referenced by an Exec Arguments: line, the ordered set
      # of argument NAMES the plan passes. Names only - values are never captured.
      param([byte[]]$Byte)

      $result = [System.Collections.ArrayList]::new()
      if ($null -eq $Byte) { return $result.ToArray() }

      $text = [System.Text.Encoding]::UTF8.GetString($Byte).TrimStart([char]0xFEFF)
      # Drop comment lines first: the plan headers legitimately mention 'Arguments:' and
      # runner script names in prose, and those must not be parsed as declarations.
      $code = (($text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")

      # Map OtterScript variables that are assigned a .ps1 path to that script's leaf name.
      $scriptVariable = @{}
      foreach ($setMatch in [regex]::Matches($code, 'set\s+\$([A-Za-z0-9_]+)\s*=([^;]*);')) {
        $leafMatch = [regex]::Match($setMatch.Groups[2].Value, '([A-Za-z0-9._\-]+\.ps1)')
        if ($leafMatch.Success) { $scriptVariable[$setMatch.Groups[1].Value] = $leafMatch.Groups[1].Value }
      }

      foreach ($argMatch in [regex]::Matches($code, 'Arguments:\s*>>(.*?)>>', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        $argumentText = $argMatch.Groups[1].Value

        $runnerScript = $null
        $fileMatch = [regex]::Match($argumentText, '-File\s+"?\$([A-Za-z0-9_]+)"?')
        if ($fileMatch.Success) {
          $runnerScript = $scriptVariable[$fileMatch.Groups[1].Value]
        } else {
          $literalMatch = [regex]::Match($argumentText, '-File\s+"?([^"\s]*[A-Za-z0-9._\-]+\.ps1)"?')
          if ($literalMatch.Success) { $runnerScript = Split-Path -Leaf $literalMatch.Groups[1].Value }
        }

        $names = [System.Collections.Generic.List[string]]::new()
        foreach ($nameMatch in [regex]::Matches($argumentText, '(?:^|\s)-([A-Za-z][A-Za-z0-9]*)\b')) {
          $name = $nameMatch.Groups[1].Value
          if ($powerShellHostSwitch -contains $name) { continue }
          if ($names -notcontains $name) { $names.Add($name) | Out-Null }
        }

        [void]$result.Add([PSCustomObject]@{
            RunnerScript  = $runnerScript
            ArgumentNames = $names.ToArray()
          })
      }

      return $result.ToArray()
    }

    function Test-ParameterAstMandatory {
      # A [Parameter(Mandatory)] with the value omitted means $true, so ExpressionOmitted
      # must be honoured or the bare form - which is the form the runners actually use -
      # would read as optional and hide the exact condition this cmdlet exists to catch.
      param([Parameter(Mandatory)]$ParameterAst)

      foreach ($attribute in @($ParameterAst.Attributes)) {
        if ($attribute -isnot [System.Management.Automation.Language.AttributeAst]) { continue }

        $attributeName = $attribute.TypeName.Name
        if ($attributeName -notin @('Parameter', 'ParameterAttribute', 'System.Management.Automation.ParameterAttribute')) { continue }

        foreach ($named in @($attribute.NamedArguments)) {
          if ($named.ArgumentName -ine 'Mandatory') { continue }
          if ($named.ExpressionOmitted) { return $true }

          $argumentText = $named.Argument.Extent.Text
          if ($argumentText -imatch '^\s*\$true\s*$' -or $argumentText -imatch '^\s*1\s*$') { return $true }
        }
      }

      # Mandatory in ANY parameter set counts as mandatory: the cmdlet cannot know which
      # set a BuildMaster invocation resolves to, and over-reporting a missing parameter
      # costs a triage, while under-reporting one costs a pipeline hung forever.
      return $false
    }

    function Get-RunnerParameterDetail {
      # Returns name AND mandatory-ness. Names alone were what forced every consumer to
      # re-parse the runner script to tell a benign unpassed optional parameter from the
      # forever-hang signature (drift-gate known limitation 1).
      param([Parameter(Mandatory)][string]$ScriptPath)

      $tokens = $null
      $parseErrors = $null
      $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$parseErrors)
      if ($null -eq $ast -or $null -eq $ast.ParamBlock) { return @() }

      # The SCRIPT-level param block is what the plan's Arguments bind to; parameters of
      # functions defined inside the runner are irrelevant to raft drift.
      return @($ast.ParamBlock.Parameters | ForEach-Object {
          [PSCustomObject]@{
            Name        = $_.Name.VariablePath.UserPath
            IsMandatory = (Test-ParameterAstMandatory -ParameterAst $_)
          }
        })
    }

    function New-PlanComparisonRecord {
      param(
        [string]$PlanName,
        [string]$PlanPath,
        [string]$ItemName,
        $RaftItem,
        [byte[]]$RaftBytes,
        [byte[]]$DiskBytes,
        $DiskFile,
        [int]$ResolvedApplicationId,
        [string]$Status,
        [string[]]$DriftReasons,
        [string[]]$InformationalReasons,
        [string]$Reason,
        $ArgumentComparison,
        $MandatoryParameterAnalysis,
        $SilentHangSignaturePresent,
        [string]$ArgumentSource,
        [int]$ItemTypeCode = $RaftItemTypeCode
      )

      [PSCustomObject]@{
        PlanName                 = $PlanName
        PlanPath                 = $PlanPath
        RaftId                   = $RaftId
        RaftItemId               = if ($RaftItem -and $RaftItem.PSObject.Properties['RaftItem_Id']) { $RaftItem.RaftItem_Id } else { $null }
        RaftItemName             = $ItemName
        RaftItemTypeCode         = $ItemTypeCode
        ApplicationId            = if ($ResolvedApplicationId -gt 0) { $ResolvedApplicationId } else { $null }
        ApplicationName          = if ([string]::IsNullOrWhiteSpace($ApplicationName)) { $null } else { $ApplicationName }
        ApplicationScoped        = ($ResolvedApplicationId -gt 0)
        RaftContentSha256        = Get-Sha256Hex -Byte $RaftBytes
        DiskContentSha256        = Get-Sha256Hex -Byte $DiskBytes
        RaftContentLength        = if ($null -eq $RaftBytes) { $null } else { $RaftBytes.Length }
        DiskContentLength        = if ($null -eq $DiskBytes) { $null } else { $DiskBytes.Length }
        ModifiedOnDate           = if ($RaftItem -and $RaftItem.PSObject.Properties['ModifiedOn_Date']) { $RaftItem.ModifiedOn_Date } else { $null }
        ModifiedByUserName       = if ($RaftItem -and $RaftItem.PSObject.Properties['ModifiedBy_User_Name']) { $RaftItem.ModifiedBy_User_Name } else { $null }
        DiskLastWriteTimeUtc     = if ($DiskFile) { $DiskFile.LastWriteTimeUtc } else { $null }
        ContentMatches           = ($Status -eq 'Match')
        NormalizedContentMatches = $null
        ArgumentSource           = $ArgumentSource
        ArgumentComparison       = $ArgumentComparison
        # The mandatory/optional split lives here so no consumer has to re-derive it.
        # $null - not $false - when the check could not run: see .OUTPUTS.
        MandatoryParameterAnalysis  = $MandatoryParameterAnalysis
        SilentHangSignaturePresent  = $SilentHangSignaturePresent
        Status                   = $Status
        DriftReasons             = $DriftReasons
        InformationalReasons     = $InformationalReasons
        Reason                   = $Reason
        BuildMasterBaseUrl       = $BuildMasterBaseUrl
        ComparedOnUtc            = [datetime]::UtcNow
      }
    }
  }

  process {
    $inputPaths = @($Path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($inputPaths.Count -eq 0) {
      throw 'Path was not supplied and BuildMaster.PlansDirectory was not found in $global:settings.'
    }

    $planFiles = [System.Collections.ArrayList]::new()
    $missingPaths = [System.Collections.ArrayList]::new()

    foreach ($candidate in $inputPaths) {
      if (Test-Path -LiteralPath $candidate -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $candidate -Filter '*.otter' -File -Recurse:$Recurse -ErrorAction Stop)) {
          [void]$planFiles.Add($file)
        }
        if ($IncludePipelines) {
          foreach ($file in @(Get-ChildItem -LiteralPath $candidate -Filter "*$pipelineFileSuffix" -File -Recurse:$Recurse -ErrorAction Stop)) {
            [void]$planFiles.Add($file)
          }
        }
        continue
      }
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        [void]$planFiles.Add((Get-Item -LiteralPath $candidate -ErrorAction Stop))
        continue
      }
      # A path that does not exist is not an error: the raft may still hold the plan,
      # which is exactly the MissingOnDisk case this cmdlet must report.
      [void]$missingPaths.Add($candidate)
    }

    if ($planFiles.Count -eq 0 -and $missingPaths.Count -eq 0) {
      throw "No .otter files found under '$($inputPaths -join ', ')'."
    }

    $totalPlans = $planFiles.Count + $missingPaths.Count
    if ($PSBoundParameters.ContainsKey('RaftItemName') -and $totalPlans -gt 1) {
      throw "RaftItemName is valid only when exactly one plan is compared; $totalPlans were resolved."
    }

    $resolvedApplicationId = $ApplicationId
    if (-not $PSBoundParameters.ContainsKey('ApplicationId') -and -not [string]::IsNullOrWhiteSpace($ApplicationName)) {
      $resolvedApplicationId = Resolve-BuildMasterApplicationId -Name $ApplicationName
    }

    foreach ($missing in $missingPaths) {
      $itemName = if ($PSBoundParameters.ContainsKey('RaftItemName')) { $RaftItemName } else { Split-Path -Leaf $missing }
      try {
        $raftItem = Get-BuildMasterRaftItem -ItemName $itemName -ResolvedApplicationId $resolvedApplicationId
        $raftBytes = ConvertTo-RaftContentByte -RaftItem $raftItem
        $status = if ($null -eq $raftItem) { 'MissingFromRaft' } else { 'MissingOnDisk' }
        $reason = if ($null -eq $raftItem) { "Plan is absent from disk and absent from raft $RaftId." } else { "Plan file '$missing' does not exist on disk; raft $RaftId still holds the item." }

        New-PlanComparisonRecord -PlanName (Split-Path -Leaf $missing) -PlanPath $missing -ItemName $itemName `
          -RaftItem $raftItem -RaftBytes $raftBytes -DiskBytes $null -DiskFile $null `
          -ResolvedApplicationId $resolvedApplicationId -Status $status -DriftReasons @($status) `
          -InformationalReasons @() -Reason $reason -ArgumentComparison @() `
          -MandatoryParameterAnalysis @() -SilentHangSignaturePresent $null -ArgumentSource 'None'
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "BuildMaster raft query failed for '$itemName'. Exception: $($_.Exception.Message)"
        New-PlanComparisonRecord -PlanName (Split-Path -Leaf $missing) -PlanPath $missing -ItemName $itemName `
          -RaftItem $null -RaftBytes $null -DiskBytes $null -DiskFile $null `
          -ResolvedApplicationId $resolvedApplicationId -Status 'Unreachable' -DriftReasons @('Unreachable') `
          -InformationalReasons @() -Reason "BuildMaster raft query failed: $($_.Exception.Message)" -ArgumentComparison @() `
          -MandatoryParameterAnalysis @() -SilentHangSignaturePresent $null -ArgumentSource 'None'
      }
    }

    foreach ($file in $planFiles) {
      $isPipeline = (Test-PipelineFile -File $file)
      $itemTypeCode = if ($isPipeline) { $pipelineRaftItemTypeCode } else { $RaftItemTypeCode }
      $itemName = if ($PSBoundParameters.ContainsKey('RaftItemName')) {
        $RaftItemName
      } elseif ($isPipeline) {
        $file.Name.Substring(0, $file.Name.Length - $pipelineFileSuffix.Length)
      } else {
        $file.Name
      }
      $planName = if ($isPipeline) { $itemName } else { $file.BaseName }
      $diskBytes = $null

      try {
        $diskBytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $raftItem = Get-BuildMasterRaftItem -ItemName $itemName -ResolvedApplicationId $resolvedApplicationId -ItemTypeCode $itemTypeCode
        $raftBytes = ConvertTo-RaftContentByte -RaftItem $raftItem

        if ($null -eq $raftItem -or $null -eq $raftBytes) {
          $reason = if ($null -eq $raftItem) {
            "Raft $RaftId has no type-$itemTypeCode item named '$itemName'$(if ($resolvedApplicationId -gt 0) { " for application $resolvedApplicationId" })."
          } else {
            "Raft item '$itemName' returned no content."
          }
          New-PlanComparisonRecord -PlanName $planName -PlanPath $file.FullName -ItemName $itemName -ItemTypeCode $itemTypeCode `
            -RaftItem $raftItem -RaftBytes $raftBytes -DiskBytes $diskBytes -DiskFile $file `
            -ResolvedApplicationId $resolvedApplicationId -Status 'MissingFromRaft' -DriftReasons @('MissingFromRaft') `
            -InformationalReasons @() -Reason $reason -ArgumentComparison @() `
            -MandatoryParameterAnalysis @() -SilentHangSignaturePresent $null -ArgumentSource 'None'
          continue
        }

        $driftReasons = [System.Collections.Generic.List[string]]::new()
        $informationalReasons = [System.Collections.Generic.List[string]]::new()

        $raftSha = Get-Sha256Hex -Byte $raftBytes
        $diskSha = Get-Sha256Hex -Byte $diskBytes
        $bytesMatch = ($raftSha -eq $diskSha)
        $normalizedMatch = ((ConvertTo-NormalizedPlanText -Byte $raftBytes) -ceq (ConvertTo-NormalizedPlanText -Byte $diskBytes))

        if (-not $bytesMatch) {
          # A whitespace-only difference is still drift - it means the raft was not written
          # from these exact bytes - but it is a materially different diagnosis.
          [void]$driftReasons.Add($(if ($normalizedMatch) { 'WhitespaceOnlyContentDrift' } else { 'ContentDrift' }))
        }

        if ($isPipeline) {
          # A pipeline has no Exec Arguments: line and no runner; only the content
          # comparison applies. $false, not $null: there is no argument list to hang on.
          $uniqueReasons = @($driftReasons | Select-Object -Unique)
          $record = New-PlanComparisonRecord -PlanName $planName -PlanPath $file.FullName -ItemName $itemName -ItemTypeCode $itemTypeCode `
            -RaftItem $raftItem -RaftBytes $raftBytes -DiskBytes $diskBytes -DiskFile $file `
            -ResolvedApplicationId $resolvedApplicationId -Status $(if ($uniqueReasons.Count -eq 0) { 'Match' } else { 'Drift' }) `
            -DriftReasons $uniqueReasons -InformationalReasons @() -Reason $null -ArgumentComparison @() `
            -MandatoryParameterAnalysis @() -SilentHangSignaturePresent $false -ArgumentSource 'NotApplicable'
          $record.ContentMatches = $bytesMatch
          $record.NormalizedContentMatches = $normalizedMatch
          $record
          continue
        }

        # Argument names are taken from the DEPLOYED raft content, because the raft plan is
        # what actually invokes the runner. The runner parameters come from disk, because
        # the runner is read from disk at run time.
        $runnerRoot = if ([string]::IsNullOrWhiteSpace($RunnerScriptDirectory)) { $file.DirectoryName } else { $RunnerScriptDirectory }
        $argumentComparison = [System.Collections.ArrayList]::new()
        $mandatoryAnalysis = [System.Collections.ArrayList]::new()
        $argumentCheckRan = $false

        foreach ($planArgument in @(Get-PlanRunnerArgument -Byte $raftBytes)) {
          $runnerPath = $null
          $runnerFound = $false
          $runnerDetails = @()

          if (-not [string]::IsNullOrWhiteSpace($planArgument.RunnerScript)) {
            $runnerPath = Join-Path $runnerRoot $planArgument.RunnerScript
            if (Test-Path -LiteralPath $runnerPath -PathType Leaf) {
              $runnerFound = $true
              $runnerDetails = @(Get-RunnerParameterDetail -ScriptPath $runnerPath)
            }
          }

          $runnerParameters = @($runnerDetails | ForEach-Object { $_.Name })
          $mandatoryParameters = @($runnerDetails | Where-Object { $_.IsMandatory } | ForEach-Object { $_.Name })

          $argumentNames = @($planArgument.ArgumentNames)
          $onlyInPlan = @($argumentNames | Where-Object { $runnerParameters -notcontains $_ })
          $onlyInRunner = @($runnerParameters | Where-Object { $argumentNames -notcontains $_ })

          # The whole point of unit 15.171.e: split the one-way asymmetry by mandatory-ness.
          # Mandatory-and-missing is the forever-hang; optional-and-missing is every healthy
          # plan in the set and must not be allowed to turn the gate red.
          $mandatoryMissing = @($onlyInRunner | Where-Object { $mandatoryParameters -contains $_ })
          $optionalMissing = @($onlyInRunner | Where-Object { $mandatoryParameters -notcontains $_ })

          if (-not $runnerFound) {
            # The check did not happen. Still Drift, because an unverifiable argument list
            # is not a verified one - see the drift gate's Sev-I row.
            [void]$driftReasons.Add('RunnerScriptMissing')
          } else {
            $argumentCheckRan = $true
            if ($mandatoryMissing.Count -gt 0) { [void]$driftReasons.Add('MandatoryArgumentMissing') }
            if ($onlyInPlan.Count -gt 0) { [void]$driftReasons.Add('UndeclaredArgument') }
            if ($optionalMissing.Count -gt 0) { [void]$informationalReasons.Add('OptionalParametersNotPassed') }

            [void]$mandatoryAnalysis.Add([PSCustomObject]@{
                RunnerScript                             = $planArgument.RunnerScript
                MandatoryRunnerParameterCount            = $mandatoryParameters.Count
                MandatoryRunnerParametersMissingFromRaft = $mandatoryMissing
                SilentHangSignaturePresent               = ($mandatoryMissing.Count -gt 0)
              })
          }

          [void]$argumentComparison.Add([PSCustomObject]@{
              RunnerScript                        = $planArgument.RunnerScript
              RunnerScriptPath                    = $runnerPath
              RunnerScriptFound                   = $runnerFound
              PlanArgumentNames                   = $argumentNames
              RunnerParameterNames                = $runnerParameters
              MandatoryRunnerParameterNames       = $mandatoryParameters
              ArgumentsNotInRunner                = $onlyInPlan
              # Retained unchanged for existing consumers; the two fields below are the
              # split of it that carries the severity.
              RunnerParametersNotInPlan           = $onlyInRunner
              MandatoryRunnerParametersNotInPlan  = $mandatoryMissing
              OptionalRunnerParametersNotInPlan   = $optionalMissing
              # Raw exactness of the two name sets. Kept as a FACT, not a verdict: it is
              # legitimately $false on a healthy plan that skips an optional parameter.
              ArgumentNamesMatch                  = ($runnerFound -and $onlyInPlan.Count -eq 0 -and $onlyInRunner.Count -eq 0)
              # The verdict field: every argument the runner must receive is passed, and
              # nothing is passed that it cannot bind.
              ArgumentBindingSatisfied            = ($runnerFound -and $onlyInPlan.Count -eq 0 -and $mandatoryMissing.Count -eq 0)
            })
        }

        $uniqueReasons = @($driftReasons | Select-Object -Unique)
        $status = if ($uniqueReasons.Count -eq 0) { 'Match' } else { 'Drift' }

        # $null when no argument check completed: a check that could not run must never be
        # reported as a check that found nothing.
        $silentHang = if ($argumentCheckRan) { @($mandatoryAnalysis | Where-Object { $_.SilentHangSignaturePresent }).Count -gt 0 } else { $null }

        $record = New-PlanComparisonRecord -PlanName $planName -PlanPath $file.FullName -ItemName $itemName -ItemTypeCode $itemTypeCode `
          -RaftItem $raftItem -RaftBytes $raftBytes -DiskBytes $diskBytes -DiskFile $file `
          -ResolvedApplicationId $resolvedApplicationId -Status $status -DriftReasons $uniqueReasons `
          -InformationalReasons @($informationalReasons | Select-Object -Unique) -Reason $null `
          -ArgumentComparison $argumentComparison.ToArray() -MandatoryParameterAnalysis $mandatoryAnalysis.ToArray() `
          -SilentHangSignaturePresent $silentHang -ArgumentSource 'Raft'

        $record.ContentMatches = $bytesMatch
        $record.NormalizedContentMatches = $normalizedMatch
        $record
      } catch {
        # Fail closed. An unreachable or failed server call is never reported as Match.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "BuildMaster raft comparison failed for '$itemName'. Exception: $($_.Exception.Message)"
        New-PlanComparisonRecord -PlanName $planName -PlanPath $file.FullName -ItemName $itemName -ItemTypeCode $itemTypeCode `
          -RaftItem $null -RaftBytes $null -DiskBytes $diskBytes -DiskFile $file `
          -ResolvedApplicationId $resolvedApplicationId -Status 'Unreachable' -DriftReasons @('Unreachable') `
          -InformationalReasons @() -Reason "BuildMaster raft comparison failed: $($_.Exception.Message)" -ArgumentComparison @() `
          -MandatoryParameterAnalysis @() -SilentHangSignaturePresent $null -ArgumentSource 'None'
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
