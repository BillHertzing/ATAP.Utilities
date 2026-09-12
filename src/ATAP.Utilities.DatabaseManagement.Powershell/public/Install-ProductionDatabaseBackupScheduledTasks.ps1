function Install-ProductionDatabaseBackupScheduledTasks {
  <#
  .SYNOPSIS
  Installs the two production-only ATAPUtilities backup tasks on the local host.

  .DESCRIPTION
  Creates exactly one Sunday full-backup task and one Monday-through-Saturday
  differential-backup task. The generated actions are fixed to ATAPUtilities,
  Production at localhost,50020, and dbEncryption.ATAPUtilities.Production.
  There is no parameter surface for another database or instance. SQL uses
  Windows integrated security under the local SvcSQLServer account. The
  host-suffixed SvcSQLServer SecretName stores only that account's password;
  the username is derived from the local computer name.

  .PARAMETER ModuleVersion
  Exact installed module version the scheduled actions import.

  .PARAMETER StartTime
  Local start time for both schedules. Defaults to 02:20.

  .EXAMPLE
  Install-ProductionDatabaseBackupScheduledTasks -Confirm
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject[]])]
  param(
    [Parameter()]
    [ValidatePattern('^0\.1\.21$')]
    [string] $ModuleVersion = '0.1.21',

    [Parameter()]
    [datetime] $StartTime = [datetime]::Today.AddHours(2).AddMinutes(20)
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    $taskPath = '\ATAP\DatabaseBackup\'
    $taskUserName = '{0}\SvcSQLServer' -f $env:COMPUTERNAME
    $credentialSecretName = 'SvcSQLServer.{0}' -f $env:COMPUTERNAME.ToLowerInvariant()
    $encryptionSecretName = 'dbEncryption.ATAPUtilities.Production'
    $definitions = @(
      @{ Name = 'ATAPUtilities-Production-WeeklyFull'; Type = 'Full'; Days = @('Sunday') },
      @{ Name = 'ATAPUtilities-Production-NightlyDifferential'; Type = 'Differential'; Days = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday') }
    )
  }

  process {
    if (-not $PSCmdlet.ShouldProcess("$taskPath (2 tasks)", 'Install Production ATAPUtilities backup schedules')) {
      return $definitions | ForEach-Object {
        [pscustomobject]@{ TaskName = $_.Name; TaskPath = $taskPath; BackupType = $_.Type; Status = 'WhatIf' }
      }
    }

    foreach ($requiredCommand in @('Get-SecretATAP', 'Get-ScheduledTask', 'New-ScheduledTaskAction', 'New-ScheduledTaskTrigger', 'New-ScheduledTaskSettingsSet', 'Register-ScheduledTask')) {
      if (-not (Get-Command -Name $requiredCommand -ErrorAction SilentlyContinue)) { throw "Required command '$requiredCommand' is unavailable." }
    }
    if (-not (Get-Module -ListAvailable -Name $mn | Where-Object { $_.Version -eq [version]$ModuleVersion })) {
      throw "Required module $mn version $ModuleVersion is not installed."
    }
    foreach ($definition in $definitions) {
      if (Get-ScheduledTask -TaskName $definition.Name -TaskPath $taskPath -ErrorAction SilentlyContinue) {
        throw "Scheduled task '$taskPath$($definition.Name)' already exists. Refusing to overwrite; inspect and remove it through a separately approved operation."
      }
    }

    $credentialRecord = Get-SecretATAP -SecretName $credentialSecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
    if ($credentialRecord -is [securestring]) {
      $taskPassword = [System.Net.NetworkCredential]::new('', $credentialRecord).Password
    }
    elseif ($credentialRecord -is [pscredential]) {
      $taskPassword = $credentialRecord.GetNetworkCredential().Password
    }
    elseif ($credentialRecord -is [string]) {
      $taskPassword = $credentialRecord
    }
    else {
      $taskPassword = [string]$credentialRecord.password
    }
    if ([string]::IsNullOrWhiteSpace($taskPassword)) {
      throw "Credential SecretName '$credentialSecretName' must resolve to the password for '$taskUserName'."
    }

    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 4)
    foreach ($definition in $definitions) {
      $commandText = @"
Import-Module '$mn' -RequiredVersion '$ModuleVersion' -ErrorAction Stop
Invoke-SqlServerBackup -DatabaseName 'ATAPUtilities' -Environment 'Production' -SqlInstance 'localhost,50020' -BackupType '$($definition.Type)' -UseTrustedConnection -ProtectAndPublish -EncryptionSecretName '$encryptionSecretName' -TrustServerCertificate -Confirm:`$false
"@
      $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($commandText))
      $action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-EncodedCommand $encodedCommand"
      $trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek $definition.Days -At $StartTime
      Register-ScheduledTask -TaskName $definition.Name -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -User $taskUserName -Password $taskPassword -RunLevel Highest -ErrorAction Stop | Out-Null
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Installed $($definition.Name) for Production ATAPUtilities using encryption SecretName '$encryptionSecretName'."
      [pscustomobject]@{
        TaskName = $definition.Name
        TaskPath = $taskPath
        BackupType = $definition.Type
        DatabaseName = 'ATAPUtilities'
        Environment = 'Production'
        SqlInstance = 'localhost,50020'
        EncryptionSecretName = $encryptionSecretName
        CredentialSecretName = $credentialSecretName
        ModuleVersion = $ModuleVersion
        Status = 'Installed'
      }
    }
    $taskPassword = $null
    $credentialRecord = $null
  }

  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "$fn complete." }
}
