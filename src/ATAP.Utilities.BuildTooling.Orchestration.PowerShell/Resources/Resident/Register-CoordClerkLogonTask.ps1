[CmdletBinding()]
param([string]$BindingPath, [string]$ExpectedBindingSha256, [string]$HostScriptPath, [string]$SignerThumbprint, [string]$ExecutionPolicy = '')

function Register-CoordClerkLogonTask {
  <#
  .SYNOPSIS
    Proposes or registers a disabled same-user interactive clerk logon task.
  .DESCRIPTION
    A pinned local descriptor and a signed host are required.
    Registration never enables/starts a task, grants authority or changes custody.
    Existing task names are refused instead of silently replaced.
    v1 descriptors: Held only, with the host derived from the pinned installed module
    folder, exactly as before.
    v2 descriptors: Held, or Active only when custody currently admits the package this
    registrar runs from (exact inventory, pinned -SignerThumbprint) and a valid,
    protected Coordination-activation-v1 record for this descriptor hash is in its window.
    The task action embeds only the host path, descriptor path and descriptor hash, so a
    package release or a renewed activation window leaves the task definition unchanged.
  .PARAMETER BindingPath
    Existing ordinary startup descriptor, provisioned through separate authority.
  .PARAMETER ExpectedBindingSha256
    Exact approved descriptor bytes; embedded in the future task action.
  .PARAMETER HostScriptPath
    The task action's script. Required for v2 and never derived from a module version
    folder. Pass the stable version-independent launcher's fixed path once it exists
    (slice 7), or an installed versioned host until then. For v1 it is optional and must
    equal the host derived from the pinned module folder.
    The host kind is decided by the leaf name, the signer being already proven equal to
    -SignerThumbprint: Start-CoordClerkResident.ps1 is the stable launcher and its task
    arguments also carry -CustodyPath (the descriptor's custodyPath) and -SignerThumbprint,
    which its entry requires; Invoke-CoordClerkResident.ps1 is a versioned host and gets
    -BindingPath, -ExpectedBindingSha256 and, for v2, -SignerThumbprint (its pinned trust
    anchor). Any other leaf is refused (ResidentHostKindUnknown).
  .PARAMETER SignerThumbprint
    Required for v2: the Authenticode signer HostScriptPath must carry, and the pin the task
    passes on to the launcher or host. Must equal custody's autoPackageAdmission.signer when
    custody has one (ResidentSignerPinMismatch).
  .PARAMETER ExecutionPolicy
    Execution policy placed on the task's pwsh command line. For v2 Active the task always
    names a deterministic policy rather than inheriting the machine default: RemoteSigned by
    default, or AllSigned as an explicit choice. Inherit is refused for v2 Active
    (ResidentExecutionPolicyRequired), and Bypass is never accepted. RemoteSigned is the default
    because the resident needs local unsigned scripts (PSFramework 1.14.457 is NotSigned, and so
    are the profile.ps1 files that load $global:settings); under AllSigned every start would
    fail. The execution policy is not the tamper control (operator threat model: development
    servers are trusted). The pinned-signer check on the Orchestration host, manifest and root
    module is. Otherwise Inherit (no flag) is the default.
  .EXAMPLE
    Register-CoordClerkLogonTask -BindingPath $path -ExpectedBindingSha256 $digest -HostScriptPath $launcher -SignerThumbprint $thumb -WhatIf
  .OUTPUTS
    ProposedOnly or RegisteredDisabled, identity, action and task location.
  .NOTES
    InteractiveToken and Limited use the launching user's current Windows SID.
  .LINK
    Invoke-CoordClerkResident.ps1
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory)][string]$BindingPath,
    [Parameter(Mandatory)][string]$ExpectedBindingSha256,
    [string]$HostScriptPath = '',
    [string]$SignerThumbprint = '',
    [ValidateSet('', 'RemoteSigned', 'AllSigned', 'Inherit')][string]$ExecutionPolicy = ''
  )
  begin {
    $fn = 'Register-CoordClerkLogonTask'; $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    if (-not (Get-Command Read-CoordResidentBinding -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'Invoke-CoordClerkResident.ps1') -BindingPath $BindingPath -ExpectedBindingSha256 $ExpectedBindingSha256 }
  }
  process {
    $binding = Read-CoordResidentBinding -Path $BindingPath -Digest $ExpectedBindingSha256
    $identity = Get-CoordResidentIdentity
    $activationAdmitted = $false
    if ($binding.schemaVersion -ceq 'CoordResidentStartup-v2') {
      if (-not $HostScriptPath) { throw 'ResidentHostPathRequired' }
      if ($SignerThumbprint -cnotmatch '\A[0-9a-fA-F]{40}\z') { throw 'ResidentSignerPinRequired' }
      $hostScript = Assert-CoordResidentPath -Path $HostScriptPath -MustExist
      if ([IO.Path]::GetExtension($hostScript) -ine '.ps1') { throw 'ResidentHostPathRequired' }
      $signature = Get-AuthenticodeSignature -LiteralPath $hostScript
      if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $SignerThumbprint) { throw 'ResidentHostSignatureRejected' }
      # Host kind is decided deterministically: the leaf name, with the signer already proven
      # equal to -SignerThumbprint above. The stable launcher's entry needs -CustodyPath and
      # -SignerThumbprint; a versioned host's param() takes neither. Any other leaf is refused.
      $hostKind = switch ([IO.Path]::GetFileName($hostScript)) {
        'Start-CoordClerkResident.ps1' { 'StableLauncher' }
        'Invoke-CoordClerkResident.ps1' { 'VersionedHost' }
        default { throw 'ResidentHostKindUnknown' }
      }
      if ($hostKind -ceq 'StableLauncher') {
        if ([string]::IsNullOrWhiteSpace([string]$binding.custodyPath)) { throw 'ResidentLauncherCustodyPathRequired' }
        $launcherCustody = Assert-CoordResidentPath -Path ([string]$binding.custodyPath)
        if ($launcherCustody.Contains('"')) { throw 'ResidentTaskArgumentRejected' }
      }
      if ($binding.mode -ceq 'Active') {
        # A deterministic policy, never the machine default (D2): RemoteSigned or AllSigned only.
        if ($ExecutionPolicy -ceq 'Inherit') { throw 'ResidentExecutionPolicyRequired' }
        try {
          $admission = Test-CoordResidentAdmission -Binding $binding -Digest $ExpectedBindingSha256
          if ($null -eq $admission) { throw 'ResidentAdmissionUnavailable' }
          # M3: custody's policy signer, when present, must equal the pin the task will carry.
          if ($admission.PolicySigner -and $admission.PolicySigner -ine $SignerThumbprint) { throw 'ResidentSignerPinMismatch' }
          # Imports and checks the custody-admitted package exactly as the host would.
          $null = Get-CoordResidentDrain -Binding $binding -Admission $admission -SignerThumbprint $SignerThumbprint
        } catch {
          if ($_.Exception.Message -cmatch '\AResident[A-Za-z]+\z') { throw $_.Exception.Message }
          throw 'ResidentActiveNotAdmitted'
        }
        $activationAdmitted = $true
      }
    } else {
      $hostKind = 'VersionedHost'
      if ($binding.mode -cne 'Held' -or -not $binding.module) { throw 'ResidentHeldInstalledBindingRequired' }
      $moduleBase = Split-Path $binding.module.manifestPath -Parent
      $expectedBase = Join-Path 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.Orchestration.PowerShell' $binding.module.version
      if ([IO.Path]::GetFullPath($moduleBase) -ine $expectedBase) { throw 'ResidentInstalledAllUsersRequired' }
      $hostScript = Assert-CoordResidentPath -Path (Join-Path $moduleBase 'Resources/Resident/Invoke-CoordClerkResident.ps1') -MustExist
      if ($HostScriptPath -and [IO.Path]::GetFullPath($HostScriptPath) -ine $hostScript) { throw 'ResidentHostPathMismatch' }
      if ((Get-FileHash -LiteralPath $hostScript).Hash -ine $binding.module.hostScriptSha256) { throw 'ResidentHostHashRejected' }
      $signature = Get-AuthenticodeSignature -LiteralPath $hostScript
      if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $binding.module.signerThumbprint) { throw 'ResidentHostSignatureRejected' }
      foreach ($pin in @(@{ Path = $binding.module.manifestPath; Digest = $binding.module.manifestSha256 }, @{ Path = $binding.module.rootModulePath; Digest = $binding.module.rootModuleSha256 })) {
        $path = Assert-CoordResidentPath -Path $pin.Path -MustExist
        if ((Get-FileHash -LiteralPath $path).Hash -ine $pin.Digest) { throw 'ResidentRegistrarPackageHashRejected' }
        $signature = Get-AuthenticodeSignature -LiteralPath $path
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $binding.module.signerThumbprint) { throw 'ResidentRegistrarPackageSignatureRejected' }
      }
    }
    $bindingFull = Assert-CoordResidentPath -Path $BindingPath -MustExist
    if ($bindingFull.Contains('"') -or $hostScript.Contains('"')) { throw 'ResidentTaskArgumentRejected' }
    $pwsh = Assert-CoordResidentPath -Path 'C:\Program Files\PowerShell\7\pwsh.exe' -MustExist
    $effectivePolicy = if ($ExecutionPolicy) { $ExecutionPolicy } elseif ($binding.schemaVersion -ceq 'CoordResidentStartup-v2' -and $binding.mode -ceq 'Active') { 'RemoteSigned' } else { 'Inherit' }
    $policyArgument = if ($effectivePolicy -cin @('RemoteSigned', 'AllSigned')) { '-ExecutionPolicy {0} ' -f $effectivePolicy } else { '' }
    $arguments = '-NoLogo -NonInteractive -WindowStyle Hidden {3}-File "{0}" -BindingPath "{1}" -ExpectedBindingSha256 "{2}"' -f $hostScript, $bindingFull, $ExpectedBindingSha256, $policyArgument
    if ($hostKind -ceq 'StableLauncher') {
      # Start-CoordClerkResident.ps1 refuses (LauncherArgumentsRequired) without these two.
      $arguments += ' -CustodyPath "{0}" -SignerThumbprint "{1}"' -f $launcherCustody, $SignerThumbprint
    } elseif ($binding.schemaVersion -ceq 'CoordResidentStartup-v2') {
      # A v2 versioned host anchors its package trust in this pin (M3), never in its own signature.
      $arguments += ' -SignerThumbprint "{0}"' -f $SignerThumbprint
    }
    $taskPath = '\ATAP\Orchestration\'; $taskName = 'CoordClerkResident'
    $description = 'Held-by-default admitted clerk host; activation requires separate authority.'
    $status = 'ProposedOnly'
    if ($PSCmdlet.ShouldProcess($taskPath + $taskName, 'Register disabled interactive same-user logon task')) {
      foreach ($name in @('Write-PSFMessage', 'Get-ScheduledTask', 'New-ScheduledTaskTrigger', 'New-ScheduledTaskPrincipal', 'New-ScheduledTaskAction', 'New-ScheduledTaskSettingsSet', 'New-ScheduledTask', 'Register-ScheduledTask')) { $null = Get-Command $name -ErrorAction Stop }
      if (Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue) { throw 'ResidentTaskAlreadyExists' }
      $trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity.WindowsSid
      $principal = New-ScheduledTaskPrincipal -UserId $identity.WindowsSid -LogonType Interactive -RunLevel Limited
      $action = New-ScheduledTaskAction -Execute $pwsh -Argument $arguments
      $settings = New-ScheduledTaskSettingsSet -Disable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
      $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description $description
      $null = Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -InputObject $task -ErrorAction Stop
      $status = 'RegisteredDisabled'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Resident logon task registered disabled; no activation or start performed.'
    }
    [pscustomobject]@{ Status = $status; TaskPath = $taskPath; TaskName = $taskName; WindowsSid = $identity.WindowsSid; Execute = $pwsh; Arguments = $arguments; Description = $description; Mode = $binding.mode; DescriptorVersion = $binding.schemaVersion; ActivationAdmitted = $activationAdmitted; ExecutionPolicy = $effectivePolicy; HostKind = $hostKind; Enabled = $false; Started = $false; CustodyChanged = $false }
  }
  end {}
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  if (-not $BindingPath -or -not $ExpectedBindingSha256) { throw 'ResidentBindingArgumentsRequired' }
  Register-CoordClerkLogonTask -BindingPath $BindingPath -ExpectedBindingSha256 $ExpectedBindingSha256 -HostScriptPath $HostScriptPath -SignerThumbprint $SignerThumbprint -ExecutionPolicy $ExecutionPolicy | ConvertTo-Json -Depth 10 -Compress
}
