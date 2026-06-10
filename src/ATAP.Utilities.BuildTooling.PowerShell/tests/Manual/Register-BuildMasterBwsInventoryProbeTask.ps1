<#
.SYNOPSIS
Registers the ad-hoc SvcBuildmaster BWS inventory scheduled task.

.DESCRIPTION
The task runs on demand. It is intentionally stored under tests/Manual so the
verification scripts remain in the repository but are not shipped as module
commands.
#>
function Register-BuildMasterBwsInventoryProbeTask {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TaskName = 'ATAP BuildMaster BWS Inventory Probe',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceAccount = "$env:COMPUTERNAME\SvcBuildmaster",

    [Parameter()]
    [ValidateSet('S4U', 'Password', 'ServiceAccount')]
    [string]$LogonType = 'S4U',

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProbeScriptPath = (Join-Path $PSScriptRoot 'Invoke-BuildMasterBwsInventoryProbe.ps1'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory = (Join-Path ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))) '_generated')
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  if (-not (Test-Path -LiteralPath $ProbeScriptPath)) {
    throw "Probe script was not found at '$ProbeScriptPath'."
  }

  $pwsh = (Get-Command -Name 'pwsh.exe' -CommandType Application -ErrorAction SilentlyContinue).Source
  if ([string]::IsNullOrWhiteSpace($pwsh)) {
    $pwsh = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  }

  $arguments = @(
    '-NoProfile'
    '-ExecutionPolicy'
    'Bypass'
    '-File'
    "`"$ProbeScriptPath`""
    '-OutputDirectory'
    "`"$OutputDirectory`""
  ) -join ' '

  $action = New-ScheduledTaskAction -Execute $pwsh -Argument $arguments
  $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).Date.AddDays(1))
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

  $principalParameters = @{
    UserId     = $ServiceAccount
    LogonType  = $LogonType
    RunLevel   = 'Highest'
  }
  $principal = New-ScheduledTaskPrincipal @principalParameters

  $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal

  $registered = $false
  if ($PSCmdlet.ShouldProcess($TaskName, "Register scheduled task as $ServiceAccount using $LogonType")) {
    if ($LogonType -eq 'Password') {
      if (-not $Credential) {
        throw 'Credential is required when -LogonType Password is used.'
      }

      Register-ScheduledTask -TaskName $TaskName -InputObject $task -User $Credential.UserName -Password $Credential.GetNetworkCredential().Password -Force -ErrorAction Stop | Out-Null
    } else {
      Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force -ErrorAction Stop | Out-Null
    }

    $registered = $true
  }

  $registeredTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

  [pscustomobject]@{
    TaskName        = $TaskName
    ServiceAccount  = $ServiceAccount
    LogonType       = $LogonType
    ProbeScriptPath = $ProbeScriptPath
    OutputDirectory = $OutputDirectory
    PowerShellPath  = $pwsh
    Registered      = $registered
    FoundAfterWrite = $null -ne $registeredTask
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  Register-BuildMasterBwsInventoryProbeTask @PSBoundParameters
}
