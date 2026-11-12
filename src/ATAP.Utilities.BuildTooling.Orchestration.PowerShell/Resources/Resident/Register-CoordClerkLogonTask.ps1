[CmdletBinding()]
param([string]$BindingPath, [string]$ExpectedBindingSha256)

function Register-CoordClerkLogonTask {
  <#
  .SYNOPSIS
    Proposes or registers a disabled same-user interactive clerk logon task.
  .DESCRIPTION
    A Held, pinned local descriptor and signed installed host are required.
    Registration never enables/starts a task, grants authority or changes custody.
    Existing task names are refused instead of silently replaced.
  .PARAMETER BindingPath
    Existing ordinary Held startup descriptor, provisioned through separate authority.
  .PARAMETER ExpectedBindingSha256
    Exact approved descriptor bytes; embedded in the future task action.
  .EXAMPLE
    Register-CoordClerkLogonTask -BindingPath $path -ExpectedBindingSha256 $digest -WhatIf
  .OUTPUTS
    ProposedOnly or RegisteredDisabled, identity, action and task location.
  .NOTES
    InteractiveToken and Limited use the launching user's current Windows SID.
  .LINK
    Invoke-CoordClerkResident.ps1
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param([Parameter(Mandatory)][string]$BindingPath, [Parameter(Mandatory)][string]$ExpectedBindingSha256)
  begin {
    $fn = 'Register-CoordClerkLogonTask'; $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    if (-not (Get-Command Read-CoordResidentBinding -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'Invoke-CoordClerkResident.ps1') -BindingPath $BindingPath -ExpectedBindingSha256 $ExpectedBindingSha256 }
  }
  process {
    $binding = Read-CoordResidentBinding -Path $BindingPath -Digest $ExpectedBindingSha256
    if ($binding.mode -cne 'Held' -or -not $binding.module) { throw 'ResidentHeldInstalledBindingRequired' }
    $identity = Get-CoordResidentIdentity
    $moduleBase = Split-Path $binding.module.manifestPath -Parent
    $expectedBase = Join-Path 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.Orchestration.PowerShell' $binding.module.version
    if ([IO.Path]::GetFullPath($moduleBase) -ine $expectedBase) { throw 'ResidentInstalledAllUsersRequired' }
    $hostScript = Assert-CoordResidentPath -Path (Join-Path $moduleBase 'Resources/Resident/Invoke-CoordClerkResident.ps1') -MustExist
    if ((Get-FileHash -LiteralPath $hostScript).Hash -ine $binding.module.hostScriptSha256) { throw 'ResidentHostHashRejected' }
    $signature = Get-AuthenticodeSignature -LiteralPath $hostScript
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $binding.module.signerThumbprint) { throw 'ResidentHostSignatureRejected' }
    foreach ($pin in @(@{ Path = $binding.module.manifestPath; Digest = $binding.module.manifestSha256 }, @{ Path = $binding.module.rootModulePath; Digest = $binding.module.rootModuleSha256 })) {
      $path = Assert-CoordResidentPath -Path $pin.Path -MustExist
      if ((Get-FileHash -LiteralPath $path).Hash -ine $pin.Digest) { throw 'ResidentRegistrarPackageHashRejected' }
      $signature = Get-AuthenticodeSignature -LiteralPath $path
      if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $binding.module.signerThumbprint) { throw 'ResidentRegistrarPackageSignatureRejected' }
    }
    $bindingFull = Assert-CoordResidentPath -Path $BindingPath -MustExist
    if ($bindingFull.Contains('"') -or $hostScript.Contains('"')) { throw 'ResidentTaskArgumentRejected' }
    $pwsh = Assert-CoordResidentPath -Path 'C:\Program Files\PowerShell\7\pwsh.exe' -MustExist
    $arguments = '-NoLogo -NonInteractive -WindowStyle Hidden -File "{0}" -BindingPath "{1}" -ExpectedBindingSha256 "{2}"' -f $hostScript, $bindingFull, $ExpectedBindingSha256
    $taskPath = '\ATAP\Orchestration\'; $taskName = 'CoordClerkResident'
    $status = 'ProposedOnly'
    if ($PSCmdlet.ShouldProcess($taskPath + $taskName, 'Register disabled interactive same-user logon task')) {
      foreach ($name in @('Write-PSFMessage', 'Get-ScheduledTask', 'New-ScheduledTaskTrigger', 'New-ScheduledTaskPrincipal', 'New-ScheduledTaskAction', 'New-ScheduledTaskSettingsSet', 'New-ScheduledTask', 'Register-ScheduledTask')) { $null = Get-Command $name -ErrorAction Stop }
      if (Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue) { throw 'ResidentTaskAlreadyExists' }
      $trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity.WindowsSid
      $principal = New-ScheduledTaskPrincipal -UserId $identity.WindowsSid -LogonType Interactive -RunLevel Limited
      $action = New-ScheduledTaskAction -Execute $pwsh -Argument $arguments
      $settings = New-ScheduledTaskSettingsSet -Disable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
      $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Held-by-default admitted clerk host; activation requires separate authority.'
      $null = Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -InputObject $task -ErrorAction Stop
      $status = 'RegisteredDisabled'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Resident logon task registered disabled; no activation or start performed.'
    }
    [pscustomobject]@{ Status = $status; TaskPath = $taskPath; TaskName = $taskName; WindowsSid = $identity.WindowsSid; Execute = $pwsh; Arguments = $arguments; Enabled = $false; Started = $false; CustodyChanged = $false }
  }
  end {}
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  if (-not $BindingPath -or -not $ExpectedBindingSha256) { throw 'ResidentBindingArgumentsRequired' }
  Register-CoordClerkLogonTask -BindingPath $BindingPath -ExpectedBindingSha256 $ExpectedBindingSha256 | ConvertTo-Json -Depth 10 -Compress
}
