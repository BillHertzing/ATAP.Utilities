<#
.SYNOPSIS
  Registers the SystemParityMonitor scheduled tasks on the local host.

.DESCRIPTION
  Reconstructed 2026-07-07 (Sprint 0012 Task 12.46.c): the original
  Register-ParityScheduledTasks.ps1 in ATAP.IAC Windows\Parity was never committed and
  the on-disk copy was corrupted to all null bytes, so this script was rewritten from
  the contract of the two intact task-action scripts it registers
  (Invoke-ParityScheduledAuditTask.ps1 and Invoke-ParityScheduledCompareTask.ps1).

  Task 12.38.e hardened the scheduled path: every host registers a local audit task
  that writes only to its own ParityState folder, and the primary host also registers
  the compare task that reads the peer share and writes drift reports. Tasks run as the
  dedicated local SvcParityAudit identity without Bitwarden or BWS access. Use S4U for
  local-only audit registration; use Password with a PSCredential when the compare task
  must authenticate to a peer SMB share. That Windows logon credential is solely for task
  registration and peer SMB access; it is not a vault credential.

.NOTES
  Dual-purpose script guard: registration only fires under `pwsh -File`; dot-sourcing
  or module import defines the function without side effects (module-loading standard).
#>

function New-ParityScheduledTaskTrigger {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Daily', 'BiWeekly')]
    [string] $Cadence,

    [Parameter(Mandatory = $true)]
    [string] $At,

    [Parameter(Mandatory = $false)]
    [string[]] $BiWeeklyDaysOfWeek = @('Monday')
  )

  if ($Cadence -eq 'Daily') {
    return New-ScheduledTaskTrigger -Daily -At $At
  }

  return New-ScheduledTaskTrigger -Weekly -WeeksInterval 2 -DaysOfWeek $BiWeeklyDaysOfWeek -At $At
}

function Register-ParityScheduledTaskS4U {
  [CmdletBinding()]
  param(
    [string] $TaskName,
    [string] $TaskPath,
    [string] $PwshPath,
    [string] $Arguments,
    [ValidateSet('Daily', 'BiWeekly')]
    [string] $Cadence,
    [string] $At,
    [string[]] $BiWeeklyDaysOfWeek,
    [string] $UserId,
    [System.Management.Automation.PSCredential] $Credential,
    [ValidateSet('Limited', 'Highest')]
    [string] $RunLevel
  )

  $scheduler = New-Object -ComObject 'Schedule.Service'
  $scheduler.Connect()
  $folderPath = $TaskPath.TrimEnd('\\')
  if ([string]::IsNullOrWhiteSpace($folderPath)) {
    $folderPath = '\\'
  }
  $folder = $scheduler.GetFolder($folderPath)
  $definition = $scheduler.NewTask(0)
  $definition.Principal.UserId = $UserId
  $definition.Principal.LogonType = 2 # TASK_LOGON_S4U
  $definition.Principal.RunLevel = if ($RunLevel -eq 'Highest') { 1 } else { 0 }
  $definition.Settings.StartWhenAvailable = $true
  $definition.Settings.MultipleInstances = 2 # TASK_INSTANCES_IGNORE_NEW
  $definition.Settings.ExecutionTimeLimit = 'PT2H'

  $startBoundary = (Get-Date).Date.Add([datetime]::ParseExact($At, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture).TimeOfDay)
  if ($startBoundary -le (Get-Date)) {
    $startBoundary = $startBoundary.AddDays(1)
  }
  $trigger = if ($Cadence -eq 'Daily') { $definition.Triggers.Create(2) } else { $definition.Triggers.Create(3) }
  $trigger.StartBoundary = $startBoundary.ToString('s', [Globalization.CultureInfo]::InvariantCulture)
  if ($Cadence -eq 'Daily') {
    $trigger.DaysInterval = 1
  } else {
    $dayFlags = @{ Sunday = 1; Monday = 2; Tuesday = 4; Wednesday = 8; Thursday = 16; Friday = 32; Saturday = 64 }
    $trigger.WeeksInterval = 2
    $trigger.DaysOfWeek = ($BiWeeklyDaysOfWeek | ForEach-Object { $dayFlags[$_] } | Measure-Object -Sum).Sum
  }

  $action = $definition.Actions.Create(0) # TASK_ACTION_EXEC
  $action.Path = $PwshPath
  $action.Arguments = $Arguments
  $null = $folder.RegisterTaskDefinition($TaskName, $definition, 6, $Credential.UserName, $Credential.GetNetworkCredential().Password, 2, $null)
}

function Assert-ParityPackageManagerProfiles {
  [CmdletBinding()]
  param(
    [AllowEmptyCollection()]
    [object[]] $Profiles = @()
  )

  $configuredIdentities = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($profile in @($Profiles)) {
    $identity = [string] $profile.Identity
    if ([string]::IsNullOrWhiteSpace($identity)) {
      throw 'Every package-manager profile must specify a non-empty Identity.'
    }
    $identity = $identity.Trim()
    if ($identity -match '[/|]') {
      throw "Package-manager profile identity '$identity' cannot contain '/' or '|'."
    }
    if (-not $configuredIdentities.Add($identity)) {
      throw "Package-manager profile identity '$identity' is configured more than once."
    }

    foreach ($pathProperty in @('PipPath', 'NpmPrefix', 'NuGetToolPath')) {
      $profilePath = [string] $profile.$pathProperty
      if (-not [string]::IsNullOrWhiteSpace($profilePath) -and -not [IO.Path]::IsPathFullyQualified($profilePath)) {
        throw "$pathProperty for identity '$identity' must be a fully qualified path."
      }
    }
  }
}

function Assert-ParityExpectedSurfaceMinimumCounts {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [hashtable] $MinimumCounts
  )

  if ($MinimumCounts.Count -eq 0) {
    throw 'ExpectedSurfaceMinimumCounts must contain at least one category.'
  }
  foreach ($category in @($MinimumCounts.Keys)) {
    if ([string]::IsNullOrWhiteSpace([string]$category)) {
      throw 'Expected surface minimum category keys must be non-empty.'
    }
    $minimumCount = 0
    if (-not [int]::TryParse([string]$MinimumCounts[$category], [ref]$minimumCount) -or $minimumCount -lt 1) {
      throw "Expected minimum count for category '$category' must be an integer of at least one."
    }
  }
}

function Read-ParityPackageManagerProfilesRegistrationConfiguration {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  try {
    $configuration = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw [InvalidOperationException]::new(
      "Package-manager profile configuration at '$Path' could not be read as JSON. ErrorType=$($_.Exception.GetType().FullName)",
      $_.Exception
    )
  }

  if ([int] $configuration.SchemaVersion -ne 1) {
    throw "Package-manager profile configuration at '$Path' has unsupported SchemaVersion '$($configuration.SchemaVersion)'; expected 1."
  }
  if (-not $configuration.PSObject.Properties['Profiles']) {
    throw "Package-manager profile configuration at '$Path' must contain a Profiles array."
  }
  if ($configuration.Profiles -isnot [array]) {
    throw "Package-manager profile configuration at '$Path' must contain Profiles as an array."
  }
  if (-not $configuration.PSObject.Properties['ExpectedSurfaceMinimumCounts'] -or
    $null -eq $configuration.ExpectedSurfaceMinimumCounts) {
    throw "Package-manager profile configuration at '$Path' must contain ExpectedSurfaceMinimumCounts."
  }

  [object[]] $profiles = @($configuration.Profiles)
  Assert-ParityPackageManagerProfiles -Profiles $profiles
  $minimumCounts = @{}
  foreach ($property in @($configuration.ExpectedSurfaceMinimumCounts.PSObject.Properties)) {
    $minimumCounts[$property.Name] = $property.Value
  }
  Assert-ParityExpectedSurfaceMinimumCounts -MinimumCounts $minimumCounts
  return [pscustomobject]@{
    SchemaVersion = 1
    Profiles = $profiles
    ExpectedSurfaceMinimumCounts = $minimumCounts
  }
}

function Write-ParityPackageManagerProfilesConfiguration {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [AllowEmptyCollection()]
    [object[]] $Profiles = @(),

    [Parameter(Mandatory = $true)]
    [hashtable] $ExpectedSurfaceMinimumCounts
  )

  if (-not [IO.Path]::IsPathFullyQualified($Path)) {
    throw "Package-manager profile configuration path '$Path' must be fully qualified."
  }
  Assert-ParityPackageManagerProfiles -Profiles $Profiles
  Assert-ParityExpectedSurfaceMinimumCounts -MinimumCounts $ExpectedSurfaceMinimumCounts
  $orderedMinimumCounts = [ordered]@{}
  foreach ($category in @($ExpectedSurfaceMinimumCounts.Keys | Sort-Object)) {
    $orderedMinimumCounts[[string]$category] = [int]$ExpectedSurfaceMinimumCounts[$category]
  }

  $directory = Split-Path -Parent $Path
  New-Item -ItemType Directory -Path $directory -Force | Out-Null
  $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
  $backupPath = "$Path.$([guid]::NewGuid().ToString('N')).bak"
  try {
    [ordered]@{
      SchemaVersion = 1
      Profiles = @($Profiles)
      ExpectedSurfaceMinimumCounts = $orderedMinimumCounts
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporaryPath -Encoding utf8 -ErrorAction Stop

    $null = Read-ParityPackageManagerProfilesRegistrationConfiguration -Path $temporaryPath
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
      [IO.File]::Replace($temporaryPath, $Path, $backupPath)
    } else {
      [IO.File]::Move($temporaryPath, $Path)
    }
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force
    }
    if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
      Remove-Item -LiteralPath $backupPath -Force
    }
  }
}

function Register-ParityScheduledTasks {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    # Local parity state root passed to the audit task.
    [string] $StatePath = 'C:\ProgramData\ATAP\ParityState',

    # Peer parity state share passed to the compare task.
    [string] $RightStatePath = '\\utat01\ParityState',

    # Peer host name passed to the compare task.
    [string] $RightHostName = 'utat01',

    # Local host name passed to both task-action scripts.
    [string] $HostName = $env:COMPUTERNAME,

    # Daily trigger times (local).
    [string] $AuditTime = '03:00',
    [string] $CompareTime = '03:30',

    [ValidateSet('AuditOnly', 'AuditAndCompare')]
    [string] $TaskSet = $(if ($env:COMPUTERNAME -ieq 'utat022') { 'AuditAndCompare' } else { 'AuditOnly' }),

    [ValidateSet('Daily', 'BiWeekly')]
    [string] $Cadence = 'Daily',

    [string[]] $BiWeeklyDaysOfWeek = @('Monday'),

    [double] $ExpectedCadenceDays = 0,

    [double] $StaleMultiplier = 1.5,

    [AllowEmptyCollection()]
    [object[]] $PackageManagerProfiles,

    [hashtable] $ExpectedSurfaceMinimumCounts,

    [string] $PackageManagerProfilesPath,

    [string] $TaskPath = '\ATAP\',

    # Dedicated local service account that owns the scheduled tasks but no vault token.
    [string] $RunAsAccountName = 'SvcParityAudit',

    [string] $UserId,

    [ValidateSet('S4U', 'Password', 'ServiceAccount')]
    [string] $LogonType = 'S4U',

    [System.Management.Automation.PSCredential] $Credential,

    # Audit-only S4U tasks should remain least-privileged. Other task/logon
    # combinations retain the historical Highest default unless explicitly overridden.
    [ValidateSet('Limited', 'Highest')]
    [string] $RunLevel
  )

  begin {
    $fn = 'Register-ParityScheduledTasks'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    $scriptRoot = $PSScriptRoot
    $pwshPath = (Get-Command -Name 'pwsh' -CommandType Application -ErrorAction Stop).Source
    $packageManagerProfilesWereBound = $PSBoundParameters.ContainsKey('PackageManagerProfiles')
    $minimumCountsWereBound = $PSBoundParameters.ContainsKey('ExpectedSurfaceMinimumCounts')
    $defaultMinimumCounts = @{
      OS = 1
      PowerShell = 1
      Services = 3
      SQL = 1
      PackageManager = 1
      Shares = 1
      ParityState = 1
    }

    if (-not $packageManagerProfilesWereBound -and -not $minimumCountsWereBound -and
      $null -ne $global:settings -and $null -ne $global:configRootKeys) {
      $sectionKey = $global:configRootKeys['SystemParityMonitorConfigRootKey']
      $profilesKey = $global:configRootKeys['SystemParityMonitorPackageManagerProfilesConfigRootKey']
      $minimumsKey = $global:configRootKeys['SystemParityMonitorExpectedSurfaceMinimumCountsConfigRootKey']
      if (-not [string]::IsNullOrWhiteSpace([string]$sectionKey) -and
        -not [string]::IsNullOrWhiteSpace([string]$profilesKey) -and
        -not [string]::IsNullOrWhiteSpace([string]$minimumsKey) -and
        $global:settings.ContainsKey($sectionKey)) {
        $section = $global:settings[$sectionKey]
        $PackageManagerProfiles = @($section[$profilesKey])
        $ExpectedSurfaceMinimumCounts = @{}
        foreach ($category in @($section[$minimumsKey].Keys)) {
          $ExpectedSurfaceMinimumCounts[$category] = $section[$minimumsKey][$category]
        }
        $packageManagerProfilesWereBound = $true
        $minimumCountsWereBound = $true
      }
    }

    $configurationWasBound = $packageManagerProfilesWereBound -or $minimumCountsWereBound
    if ($configurationWasBound) {
      if (-not $packageManagerProfilesWereBound) {
        $PackageManagerProfiles = @()
      }
      if (-not $minimumCountsWereBound) {
        $ExpectedSurfaceMinimumCounts = $defaultMinimumCounts
      }
      if ([string]::IsNullOrWhiteSpace($PackageManagerProfilesPath)) {
        $PackageManagerProfilesPath = Join-Path $StatePath 'Configuration\PackageManagerProfiles.v1.json'
      }
      if (-not [IO.Path]::IsPathFullyQualified($PackageManagerProfilesPath)) {
        throw "PackageManagerProfilesPath '$PackageManagerProfilesPath' must be fully qualified."
      }
      Assert-ParityPackageManagerProfiles -Profiles $PackageManagerProfiles
      Assert-ParityExpectedSurfaceMinimumCounts -MinimumCounts $ExpectedSurfaceMinimumCounts
    } elseif (-not [string]::IsNullOrWhiteSpace($PackageManagerProfilesPath)) {
      throw 'PackageManagerProfilesPath cannot be supplied unless profiles or expected minimum counts are also supplied for validated materialization.'
    }
    if ([string]::IsNullOrWhiteSpace($UserId)) {
      $UserId = if ($Credential) {
        $Credential.UserName
      } else {
        "$env:COMPUTERNAME\$RunAsAccountName"
      }
    }

    if ($LogonType -eq 'Password' -and -not $Credential) {
      throw 'Credential is required when -LogonType Password is used.'
    }

    if ($Credential -and $Credential.UserName -ne $UserId) {
      throw "Credential.UserName ('$($Credential.UserName)') must match UserId ('$UserId') when a credential is supplied."
    }

    if ($ExpectedCadenceDays -le 0) {
      $ExpectedCadenceDays = if ($Cadence -eq 'BiWeekly') { 14 } else { 1 }
    }

    if ([string]::IsNullOrWhiteSpace($RunLevel)) {
      $RunLevel = if ($TaskSet -eq 'AuditOnly' -and $LogonType -eq 'S4U') {
        'Limited'
      } else {
        'Highest'
      }
    }
  }

  process {
    $auditArguments = "-StatePath `"$StatePath`" -HostName `"$HostName`""
    if ($configurationWasBound) {
      if ($PSCmdlet.ShouldProcess($PackageManagerProfilesPath, 'Write package-manager profile configuration')) {
        Write-ParityPackageManagerProfilesConfiguration `
          -Path $PackageManagerProfilesPath `
          -Profiles $PackageManagerProfiles `
          -ExpectedSurfaceMinimumCounts $ExpectedSurfaceMinimumCounts
      }
      $auditArguments += " -PackageManagerProfilesPath `"$PackageManagerProfilesPath`""
    }

    $definitions = @(
      @{
        TaskName = 'ATAP-ParityAudit'
        ScriptName = 'Invoke-ParityScheduledAuditTask.ps1'
        Arguments = $auditArguments
        At = $AuditTime
      }
    )

    if ($TaskSet -eq 'AuditAndCompare') {
      $compareArguments = "-LeftStatePath `"$StatePath`" -RightStatePath `"$RightStatePath`" -LeftHostName `"$HostName`" -RightHostName `"$RightHostName`" -ExpectedCadenceDays $ExpectedCadenceDays -StaleMultiplier $StaleMultiplier"
      if ($configurationWasBound) {
        $compareArguments += " -PackageManagerProfilesPath `"$PackageManagerProfilesPath`""
      }

      $definitions += @{
        TaskName = 'ATAP-ParityCompare'
        ScriptName = 'Invoke-ParityScheduledCompareTask.ps1'
        Arguments = $compareArguments
        At = $CompareTime
      }
    }

    foreach ($definition in $definitions) {
      $scriptPath = Join-Path $scriptRoot $definition.ScriptName
      if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Task-action script was not found at '$scriptPath'."
      }

      # UTAT01's PowerShell 7 endpoint intentionally cannot discover the inbox
      # ScheduledTasks module. Credential-backed S4U registration uses Task Scheduler
      # COM exclusively, so do not resolve any ScheduledTasks cmdlet on that path.
      $usesComS4URegistration = $LogonType -eq 'S4U' -and $null -ne $Credential
      if (-not $usesComS4URegistration) {
        $action = New-ScheduledTaskAction -Execute $pwshPath `
          -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" $($definition.Arguments)"
        $trigger = New-ParityScheduledTaskTrigger -Cadence $Cadence -At $definition.At -BiWeeklyDaysOfWeek $BiWeeklyDaysOfWeek
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
          -AllowStartIfOnBatteries `
          -DontStopIfGoingOnBatteries `
          -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2)
        $principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType $LogonType -RunLevel $RunLevel
      }

      if ($PSCmdlet.ShouldProcess("$($definition.TaskName) -> $scriptPath", 'Register scheduled task')) {
        if ($usesComS4URegistration) {
          Register-ParityScheduledTaskS4U `
            -TaskName $definition.TaskName -TaskPath $TaskPath -PwshPath $pwshPath `
            -Arguments "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" $($definition.Arguments)" `
            -Cadence $Cadence -At $definition.At -BiWeeklyDaysOfWeek $BiWeeklyDaysOfWeek `
            -UserId $UserId -Credential $Credential -RunLevel $RunLevel
        } elseif ($Credential) {
          $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal
          Register-ScheduledTask -TaskName $definition.TaskName -TaskPath $TaskPath `
            -InputObject $task -User $Credential.UserName -Password $Credential.GetNetworkCredential().Password `
            -Force -ErrorAction Stop | Out-Null
        } else {
          Register-ScheduledTask -TaskName $definition.TaskName -TaskPath $TaskPath `
            -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
            -Force -ErrorAction Stop | Out-Null
        }

        if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "Registered scheduled task '$($definition.TaskName)' -> '$scriptPath'." -Tag 'ScheduledTask'
        }
      }
    }
  }

  end {
  }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  # Fires ONLY under: pwsh -File <script>; skipped on dot-source, module import, and &.
  Register-ParityScheduledTasks @args
}
