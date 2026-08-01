function Invoke-BWSReadOnlyTokenBootstrap {
  <#
  .SYNOPSIS
    Runs the bounded scheduled-task transport for an approved BWS ReadOnly bootstrap envelope.
  .DESCRIPTION
    Registers one short-lived Password-logon scheduled task under an explicitly supplied
    PSCredential. The approved service account decrypts its account-specific CMS envelope
    with its CurrentUser private key and writes only the ReadOnly DPAPI slot. Task arguments
    contain no token. CI-Shared and ReadOnly are fixed policy outputs.
  .PARAMETER AccountName
    Local approved service account.
  .PARAMETER ServiceLogonCredential
    Explicit Task Scheduler Password-logon credential for the same approved account.
  .PARAMETER EnvelopePath
    Existing account-specific CMS envelope created by New-BWSReadOnlyBootstrapEnvelope.
  .PARAMETER CertificateThumbprint
    Thumbprint of the matching private certificate in the worker account CurrentUser store.
  .PARAMETER CredentialDirectory
    Target account credential directory. Defaults under ProgramData for the approved SAM name.
  .PARAMETER TimeoutSeconds
    Bounded wait for the one-shot task. Defaults to 300 seconds.
  .PARAMETER Force
    Repairs a stale deterministic task or replaces an existing ReadOnly DPAPI slot.
  .OUTPUTS
    Redacted status object. No token or password is returned.
  .EXAMPLE
    $parameters = @{
      AccountName = '.\SvcProGet'
      ServiceLogonCredential = $credential
      EnvelopePath = '.\bootstrap.cms'
      CertificateThumbprint = $thumbprint
      WhatIf = $true
    }
    Invoke-BWSReadOnlyTokenBootstrap @parameters
  .NOTES
    Does not create certificates, accounts, passwords, logon rights, or Bitwarden grants.
  .LINK
    New-BWSReadOnlyBootstrapEnvelope
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AccountName,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$ServiceLogonCredential,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvelopePath,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Fa-f0-9]{40}$')]
    [string]$CertificateThumbprint,

    [string]$CredentialDirectory,

    [ValidateRange(30, 1800)]
    [int]$TimeoutSeconds = 300,

    [switch]$Force
  )

  begin {
    $fn = 'Invoke-BWSReadOnlyTokenBootstrap'
    $mn = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started.' -Tag 'bws-bootstrap'
    if (-not (Get-Command -Name 'Resolve-BWSReadOnlyBootstrapIdentity' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..\private\Resolve-BWSReadOnlyBootstrapIdentity.ps1')
    }
  }

  process {
    $identity = Resolve-BWSReadOnlyBootstrapIdentity -AccountName $AccountName
    $credentialIdentity = Resolve-BWSReadOnlyBootstrapIdentity -AccountName $ServiceLogonCredential.UserName
    if ($credentialIdentity.AccountName -ne $identity.AccountName) {
      throw 'ServiceLogonCredential identity does not match the approved bootstrap account.'
    }

    $resolvedEnvelopePath = [IO.Path]::GetFullPath($EnvelopePath)
    if (-not (Test-Path -LiteralPath $resolvedEnvelopePath -PathType Leaf)) {
      throw "Encrypted bootstrap envelope was not found at '$resolvedEnvelopePath'."
    }
    if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
      $CredentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$($identity.SamAccountName)"
    }
    $canonicalCredentialDirectory = [IO.Path]::GetFullPath(
      "C:\ProgramData\ATAP\BitwardenCredentials\$($identity.SamAccountName)")
    $CredentialDirectory = [IO.Path]::GetFullPath($CredentialDirectory)
    if ($CredentialDirectory -ne $canonicalCredentialDirectory) {
      throw "CredentialDirectory must be the canonical path for '$($identity.SamAccountName)'."
    }
    if (-not (Test-Path -LiteralPath $CredentialDirectory -PathType Container)) {
      throw "Canonical credential directory is unavailable for '$($identity.SamAccountName)'."
    }

    $tokenFileName = '{0}_{1}_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml' -f $env:COMPUTERNAME, $identity.SamAccountName
    $tokenPath = Join-Path $CredentialDirectory $tokenFileName
    $taskPath = '\ATAP\'
    $taskName = 'ATAP-BWS-ReadOnly-Bootstrap-{0}-{1}' -f $env:COMPUTERNAME, $identity.SamAccountName
    $operationId = [Guid]::NewGuid().ToString('N')
    $stopAndUnregisterTask = {
      param([Parameter(Mandatory)][string]$Name)

      $taskToRemove = Get-ScheduledTask -TaskPath $taskPath -TaskName $Name -ErrorAction SilentlyContinue
      if (-not $taskToRemove) {
        return
      }
      if ($taskToRemove.State -eq 'Running') {
        Stop-ScheduledTask -TaskPath $taskPath -TaskName $Name -ErrorAction Stop
        $stopDeadline = (Get-Date).AddSeconds(10)
        do {
          Start-Sleep -Milliseconds 250
          $taskToRemove = Get-ScheduledTask -TaskPath $taskPath -TaskName $Name -ErrorAction Stop
        } while ($taskToRemove.State -eq 'Running' -and (Get-Date) -lt $stopDeadline)
        if ($taskToRemove.State -eq 'Running') {
          throw "Scheduled task '$Name' could not be verified stopped."
        }
      }
      Unregister-ScheduledTask -TaskPath $taskPath -TaskName $Name -Confirm:$false -ErrorAction Stop
    }
    $baseResult = [ordered]@{
      Status       = $null
      OperationId  = $operationId
      AccountName  = $identity.AccountName
      ProjectName  = $identity.ProjectName
      TokenPurpose = $identity.TokenPurpose
      TaskPath      = $taskPath
      TaskName      = $taskName
      TokenPath     = $tokenPath
    }

    if ((Test-Path -LiteralPath $tokenPath -PathType Leaf) -and -not $Force) {
      $baseResult.Status = 'ExistingUnverified'
      return [PSCustomObject]$baseResult
    }

    $existingTask = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask -and -not $Force) {
      $baseResult.Status = if ($existingTask.State -eq 'Running') { 'InProgress' } else { 'NeedsOperator' }
      return [PSCustomObject]$baseResult
    }

    $actionDescription = "Bootstrap CI-Shared ReadOnly token for $($identity.AccountName) using Password task logon"
    if (-not $PSCmdlet.ShouldProcess($taskName, $actionDescription)) {
      $baseResult.Status = 'Planned'
      return [PSCustomObject]$baseResult
    }

    $wasRepair = $null -ne $existingTask
    if ($existingTask) {
      & $stopAndUnregisterTask $taskName
    }

    $workerPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\private\Invoke-BWSReadOnlyBootstrapWorker.ps1'))
    $pwshPath = (Get-Command -Name 'pwsh.exe' -CommandType Application -ErrorAction Stop).Source
    $quote = {
      param([string]$Value)
      "'$($Value.Replace("'", "''"))'"
    }
    $workerCommandParts = @(
      ". $(& $quote $workerPath)"
      "Invoke-BWSReadOnlyBootstrapWorker -EnvelopePath $(& $quote $resolvedEnvelopePath)"
      "-AccountName $(& $quote $identity.AccountName)"
      "-CertificateThumbprint $(& $quote $CertificateThumbprint)"
      "-CredentialDirectory $(& $quote $CredentialDirectory)"
      "-Force:`$$($Force.IsPresent)"
    )
    $workerCommand = $workerCommandParts -join ' '
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("& { $workerCommand }"))
    $taskArguments = "-NonInteractive -EncodedCommand $encodedCommand"

    $action = New-ScheduledTaskAction -Execute $pwshPath -Argument $taskArguments
    $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(5))
    $settingsParameters = @{
      ExecutionTimeLimit    = New-TimeSpan -Seconds $TimeoutSeconds
      AllowStartIfOnBatteries = $true
      DontStopIfGoingOnBatteries = $true
    }
    $settings = New-ScheduledTaskSettingsSet @settingsParameters
    $principal = New-ScheduledTaskPrincipal -UserId $identity.AccountName -LogonType Password -RunLevel Highest
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal

    try {
      $registerParameters = @{
        TaskName   = $taskName
        TaskPath   = $taskPath
        InputObject = $task
        User       = $ServiceLogonCredential.UserName
        Password   = $ServiceLogonCredential.GetNetworkCredential().Password
        Force      = $true
        ErrorAction = 'Stop'
      }
      Register-ScheduledTask @registerParameters | Out-Null
      $taskStartTime = Get-Date
      Start-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop

      $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
      do {
        Start-Sleep -Milliseconds 500
        $taskState = (Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop).State
        $taskInfo = Get-ScheduledTaskInfo -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop
        $taskHasRun = $taskInfo.LastRunTime -ge $taskStartTime
      } while ((-not $taskHasRun -or $taskState -eq 'Running') -and (Get-Date) -lt $deadline)

      if (-not $taskHasRun -or $taskState -eq 'Running') {
        throw 'BWS ReadOnly bootstrap task exceeded its bounded execution time.'
      }
      if ($taskInfo.LastTaskResult -ne 0 -or -not (Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
        throw 'BWS ReadOnly bootstrap task did not produce a verified DPAPI file.'
      }

      Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false -ErrorAction Stop
      $baseResult.Status = if ($wasRepair) { 'Repaired' } else { 'Provisioned' }
      $baseResult['ExitCode'] = $taskInfo.LastTaskResult
      [PSCustomObject]$baseResult
    } catch {
      try {
        & $stopAndUnregisterTask $taskName
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "BWS ReadOnly bootstrap cleanup could not verify the task stopped for operation '$operationId'." -Tag 'bws-bootstrap'
        throw "BWS ReadOnly bootstrap requires operator cleanup for operation '$operationId'."
      }
      Remove-Item -LiteralPath $resolvedEnvelopePath -Force -ErrorAction SilentlyContinue
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "BWS ReadOnly bootstrap failed closed for operation '$operationId'." -Tag 'bws-bootstrap'
      throw "BWS ReadOnly bootstrap failed closed for operation '$operationId'."
    } finally {
      $registerParameters.Password = $null
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed.' -Tag 'bws-bootstrap'
  }
}
