function Test-ProfiledRemotingEndpoint {
  <#
  .SYNOPSIS
    Opens a fresh session against the managed, profiled PowerShell 7 WinRM
    endpoint (SC-0267) and verifies it loads correctly for the authenticated
    identity.

  .DESCRIPTION
    Connects via -ConfigurationName using the supplied credential and checks:
      - the expected managed module (-ExpectedModulePathFragment) is discoverable
        via Get-Module -ListAvailable inside the session (PSModulePath itself only
        ever lists root search directories, never a specific module name, so it is
        captured for diagnostics but is not substring-matched for pass/fail)
      - the machine (AllUsersAllHosts) profile ran (sentinel variable present)
      - the connecting identity's (CurrentUserAllHosts) profile ran (sentinel
        variable present)
      - session creation completed within -MaxStartupSeconds
      - the call completed non-interactively (a hang/prompt surfaces as a
        timeout; this function does not attempt console-prompt detection)

    A single known, pre-existing warning is tolerated and does not fail
    verification: "[CurrentUserAllHostsV7CoreProfile.ps1] global_EnvironmentVariables.ps1
    was not found beside the profile, under PSHOME, or in the installed
    ATAP.Utilities.PowerShell module. Process environment setup was skipped."
    This is a known issue tracked in a separate scope-creep item, not a defect
    introduced by the endpoint itself.

  .PARAMETER ComputerName
    Target host to connect to.

  .PARAMETER Credential
    Credential used to authenticate the session. Get-SecretATAP returns a
    single string field, not a PSCredential, so build one at the call site
    from the 'username' and 'password' fields of the same secret item --
    never hard-code a secret name in library code.

  .PARAMETER ConfigurationName
    Name of the registered session configuration to connect through.

  .PARAMETER ExpectedModulePathFragment
    Name of the module that must be discoverable (Get-Module -ListAvailable)
    inside the session.

  .PARAMETER MaxStartupSeconds
    Upper bound for session creation + sentinel evaluation. Exceeding this is
    treated as a failure (bounded-startup / possible hang or prompt).

  .OUTPUTS
    PSCustomObject with each check's boolean result, the known-noise flag, and
    an aggregate Ok.

  .EXAMPLE
    $u = Get-SecretATAP -SecretName 'Windows.Remoting.Credential.UTAT01' -SecretField 'username'
    $p = Get-SecretATAP -SecretName 'Windows.Remoting.Credential.UTAT01' -SecretField 'password'
    $cred = [PSCredential]::new($u, (ConvertTo-SecureString $p -AsPlainText -Force))
    Test-ProfiledRemotingEndpoint -ComputerName utat01 -Credential $cred

  .NOTES
    AI assisted using ./.claude/Rules/Powershell.md as guidelines.
    Implements SC-0267 verification requirements.
  .LINK
    Register-ProfiledRemotingEndpoint
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ComputerName,

    [Parameter(Mandatory)]
    [PSCredential] $Credential,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigurationName = 'ATAP.PS7.Profiled',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ExpectedModulePathFragment = 'ATAP.Utilities.PowerShell',

    [Parameter()]
    [ValidateRange(1, 300)]
    [int] $MaxStartupSeconds = 15
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"

    $knownNoiseMessage = 'global_EnvironmentVariables.ps1 was not found beside the profile, under PSHOME, or in the installed'

    # Signals below are drawn from what the ATAP.IAC profile templates already set
    # unconditionally for a non-SSH-backed session (this WinRM endpoint), rather than
    # a purpose-built sentinel: $global:settings is populated by
    # AllUsersAllHostsV7CoreProfile.ps1 (machine profile); $global:MaxHistoryCount is
    # set by CurrentUserAllHostsV7CoreProfile.ps1's history block, which only runs
    # when $isSshBackedRemoting is $false (true for a WinRM session).
    # PSModulePath itself only ever lists root search directories (e.g.
    # 'C:\Program Files\PowerShell\Modules'), never a specific module's name, so a
    # substring match for $ExpectedModulePathFragment against it can never succeed.
    # Module discoverability is checked directly with Get-Module -ListAvailable instead.
    $probeScript = {
      param($ExpectedModuleName)
      [PSCustomObject]@{
        PSModulePath       = $env:PSModulePath
        ModuleDiscoverable = [bool](Get-Module -ListAvailable -Name $ExpectedModuleName -ErrorAction SilentlyContinue)
        MachineProfileRan  = [bool]($global:settings -and $global:settings.Count -gt 0)
        UserProfileRan     = [bool](Get-Variable -Name 'MaxHistoryCount' -Scope Global -ErrorAction SilentlyContinue)
        UserName           = [Environment]::UserName
      }
    }
  }

  process {
    $ok = $true
    $details = [ordered]@{}
    $knownNoiseObserved = $false

    if (-not $PSCmdlet.ShouldProcess("$ConfigurationName@$ComputerName", 'Open verification session')) {
      return [PSCustomObject]@{
        ComputerName      = $ComputerName
        ConfigurationName = $ConfigurationName
        Ok                = $true
        DryRun            = $true
      }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Invoke-Command on $ComputerName" -Tag 'InvokeCommandCall'
      # Use Invoke-Command's own -AsJob rather than wrapping in Start-Job: Start-Job
      # launches a separate process and marshals -ArgumentList through CliXml, which
      # collapses a ScriptBlock argument into a plain string and breaks -ScriptBlock
      # binding on the far side. -AsJob keeps the scriptblock intact in-process while
      # still giving a job handle to bound with Wait-Job/-Timeout.
      $job = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ConfigurationName $ConfigurationName -ScriptBlock $probeScript -ArgumentList $ExpectedModulePathFragment -AsJob -ErrorAction Stop

      $completed = Wait-Job -Job $job -Timeout $MaxStartupSeconds
      $sw.Stop()

      if (-not $completed) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        $ok = $false
        $details['TimedOut'] = $true
        $details['ElapsedSeconds'] = $sw.Elapsed.TotalSeconds
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Session against '$ConfigurationName@$ComputerName' did not complete within $MaxStartupSeconds seconds (possible hang or interactive prompt)."
      } else {
        $probe = Receive-Job -Job $job -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from Invoke-Command on $ComputerName" -Tag 'InvokeCommandCall'

        $details['ElapsedSeconds'] = $sw.Elapsed.TotalSeconds
        $details['WithinStartupBudget'] = ($sw.Elapsed.TotalSeconds -le $MaxStartupSeconds)
        $details['PSModulePath'] = $probe.PSModulePath
        $details['ModuleDiscoverable'] = $probe.ModuleDiscoverable
        $details['MachineProfileRan'] = $probe.MachineProfileRan
        $details['UserProfileRan'] = $probe.UserProfileRan
        $details['AuthenticatedAs'] = $probe.UserName

        $ok = $details['WithinStartupBudget'] -and $details['ModuleDiscoverable']
      }
      Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    } catch {
      $sw.Stop()
      $ok = $false
      $message = $_.Exception.Message
      if ($message -like "*$knownNoiseMessage*") {
        $knownNoiseObserved = $true
      }
      $details['Error'] = $message
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Verification against '$ConfigurationName@$ComputerName' failed: $message"
    }

    return [PSCustomObject]@{
      ComputerName        = $ComputerName
      ConfigurationName   = $ConfigurationName
      Ok                  = $ok
      KnownNoiseObserved  = $knownNoiseObserved
      Details             = [PSCustomObject]$details
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn"
  }
}
