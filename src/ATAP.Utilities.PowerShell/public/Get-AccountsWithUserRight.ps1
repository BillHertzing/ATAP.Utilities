function Get-AccountsWithUserRight {
  <#
   .SYNOPSIS
     Gets all accounts that are assigned a specified privilege
   .DESCRIPTION
     Retrieves a list of all accounts that hold a specified right (privilege). The accounts returned are those that hold the specified privilege directly through the user account, not as part of membership to a group. A list of SIDs and account names is returned. For each SID that cannot be resolved to a name, the Account property is set to an empty string ("").
   .PARAMETER Right
     Name of the right to query. More than one right may be listed.

     Possible values:
       SeTrustedCredManAccessPrivilege              Access Credential Manager as a trusted caller
       SeNetworkLogonRight                          Access this computer from the network
       SeTcbPrivilege                               Act as part of the operating system
       SeMachineAccountPrivilege                    Add workstations to domain
       SeIncreaseQuotaPrivilege                     Adjust memory quotas for a process
       SeInteractiveLogonRight                      Allow log on locally
       SeRemoteInteractiveLogonRight                Allow log on through Remote Desktop Services
       SeBackupPrivilege                            Back up files and directories
       SeChangeNotifyPrivilege                      Bypass traverse checking
       SeSystemtimePrivilege                        Change the system time
       SeTimeZonePrivilege                          Change the time zone
       SeCreatePagefilePrivilege                    Create a pagefile
       SeCreateTokenPrivilege                       Create a token object
       SeCreateGlobalPrivilege                      Create global objects
       SeCreatePermanentPrivilege                   Create permanent shared objects
       SeCreateSymbolicLinkPrivilege                Create symbolic links
       SeDebugPrivilege                             Debug programs
       SeDenyNetworkLogonRight                      Deny access this computer from the network
       SeDenyBatchLogonRight                        Deny log on as a batch job
       SeDenyServiceLogonRight                      Deny log on as a service
       SeDenyInteractiveLogonRight                  Deny log on locally
       SeDenyRemoteInteractiveLogonRight            Deny log on through Remote Desktop Services
       SeEnableDelegationPrivilege                  Enable computer and user accounts to be trusted for delegation
       SeRemoteShutdownPrivilege                    Force shutdown from a remote system
       SeAuditPrivilege                             Generate security audits
       SeImpersonatePrivilege                       Impersonate a client after authentication
       SeIncreaseWorkingSetPrivilege                Increase a process working set
       SeIncreaseBasePriorityPrivilege              Increase scheduling priority
       SeLoadDriverPrivilege                        Load and unload device drivers
       SeLockMemoryPrivilege                        Lock pages in memory
       SeBatchLogonRight                            Log on as a batch job
       SeServiceLogonRight                          Log on as a service
       SeSecurityPrivilege                          Manage auditing and security log
       SeRelabelPrivilege                           Modify an object label
       SeSystemEnvironmentPrivilege                 Modify firmware environment values
       SeDelegateSessionUserImpersonatePrivilege    Obtain an impersonation token for another user in the same session
       SeManageVolumePrivilege                      Perform volume maintenance tasks
       SeProfileSingleProcessPrivilege              Profile single process
       SeSystemProfilePrivilege                     Profile system performance
       SeUnsolicitedInputPrivilege                  "Read unsolicited input from a terminal device"
       SeUndockPrivilege                            Remove computer from docking station
       SeAssignPrimaryTokenPrivilege                Replace a process level token
       SeRestorePrivilege                           Restore files and directories
       SeShutdownPrivilege                          Shut down the system
       SeSyncAgentPrivilege                         Synchronize directory service data
       SeTakeOwnershipPrivilege                     Take ownership of files or other objects
   .PARAMETER Computer
     Specifies the name of the computer on which to run this cmdlet. If the input for this parameter is omitted, then the cmdlet runs on the local computer.
   .PARAMETER SidForUnresolvedName
     For each SID that cannot be resolved to a name, set the Account property to the SID instead of leaving it blank.
   .EXAMPLE
     Get-AccountsWithUserRight SeServiceLogonRight

     Returns a list of all accounts that hold the "Log on as a service" right.
   .EXAMPLE
     Get-AccountsWithUserRight -Right SeServiceLogonRight,SeDebugPrivilege -Computer TESTPC

     Returns a list of accounts that hold the "Log on as a service" right, and a list of accounts that hold the "Debug programs" right, on the TESTPC system.
   .INPUTS
     PS_LSA.Rights Right
     String Computer
     Switch SidForUnresolvedName
   .OUTPUTS
     String Account
     String SID
     String Right
    .Attribution
      [How to list the users under login as a service local security policy using power-shell](https://stackoverflow.com/questions/58763479/how-to-list-the-users-under-login-as-a-service-local-security-policy-using-power)
   .LINK
     http://msdn.microsoft.com/en-us/library/ms721792.aspx
     http://msdn.microsoft.com/en-us/library/bb530716.aspx
     https://stackoverflow.com/questions/58763479/how-to-list-the-users-under-login-as-a-service-local-security-policy-using-power
  #>
  [CmdletBinding()]
  param (
    [Parameter(Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
    [Alias('Privilege')] [PS_LSA.Rights[]] $Right,
    [Parameter(ValueFromPipelineByPropertyName = $true, HelpMessage = 'Computer name')]
    [Alias('System', 'ComputerName', 'Host')][String] $Computer,
    [switch] $SidForUnresolvedName
  )
    process {
    $lsa = New-Object PS_LSA.LsaWrapper($Computer)
    foreach ($Priv in $Right) {
      $sids = $lsa.EnumerateAccountsWithUserRight($Priv, $false)
      foreach ($sid in $sids) {
        $output = @{'Account' = (Convert-SIDtoName $sid $SidForUnresolvedName); 'SID' = $sid; 'Right' = $Priv; }
        Write-Output (New-Object -TypeName PSObject -Prop $output)
      }
    }
  }
} # Gets all accounts that are assigned specified rights
