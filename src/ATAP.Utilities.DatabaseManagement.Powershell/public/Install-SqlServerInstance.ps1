function Install-SqlServerInstance {
  <#
  .SYNOPSIS
  Creates a SQL Server instance on an existing SQL Server host.

  .DESCRIPTION
  Uses dbatools Install-DbaInstance to create/configure a SQL Server instance on a host
  where SQL Server software is already present.

  Data, log, and backup paths are mandatory topology data. The cmdlet resolves them
  from the target host and instance row in $global:settings and passes them to
  Install-DbaInstance. It does not synthesize or override those locations locally.

  This cmdlet is intentionally not converted to Resolve-DatabaseSqlConnection for the
  target instance. The target SQL Server instance may not exist until Install-DbaInstance
  completes, so requiring an already-open SqlConnection would make instance creation
  impossible. Use the shared database connection resolver only if a future change adds
  a separate preflight check against an already-existing SQL Server instance.

  Authentication behavior:
  - Without CredentialsKey: uses IntegratedSecurity context.
  - With CredentialsKey: resolves UserName/Password from Bitwarden and prepares
    PSCredential for mixed-mode SA setup.

  .PARAMETER DatabaseHost
  Host where the SQL Server instance will be created.

  .PARAMETER SqlInstance
  Instance name to create on DatabaseHost.
  Use 'MSSQLSERVER' or empty for default instance.

  .PARAMETER ConnectionMethod
  Connection method metadata for downstream connection-string usage.
  Valid values: 'tcp', 'np', 'lpc'.

  .PARAMETER Port
  TCP port to configure for the instance.

  .PARAMETER IntegratedSecurity
  Use Windows integrated security context.
  Default when CredentialsKey is not supplied.

  .PARAMETER CredentialsKey
  Bitwarden key used to retrieve UserName/Password.
  Used for SQL-auth context and mixed-mode SA credential setup.

  .PARAMETER EngineCredentialSecretName
  Approved Bitwarden SecretName containing the Windows service account username and
  password passed to dbatools as EngineCredential. The secret value is never returned
  or logged.

  .PARAMETER EngineCredential
  Pre-resolved Windows service credential, normally supplied across an authenticated
  remoting boundary after local SecretName resolution. Mutually exclusive with
  EngineCredentialSecretName.

  .PARAMETER Version
  SQL Server version value for dbatools instance creation.
  Examples:  '2022', '2025''.  Default:'2022'

  .PARAMETER Feature
  Feature set passed to dbatools. Default: 'Default'.

  .PARAMETER AuthenticationMode
  SQL Server authentication mode: 'Windows' or 'Mixed'.

  .PARAMETER AdminAccount
  Optional sysadmin account(s) to assign.

  .PARAMETER SqlServerSetupPath
  Path to the extracted SQL Server setup media folder containing setup.exe.
  Required by dbatools Install-DbaInstance even when SQL Server is already installed —
  the media is needed to add a new named instance. Default: 'D:\Temp\SQLExpr\extracted'.

  .OUTPUTS
  PSCustomObject containing request metadata and dbatools output.

  .EXAMPLE
  Install-SqlServerInstance -DatabaseHost 'localhost' -SqlInstance 'Integration' -Version '2022' -IntegratedSecurity
  Creates a named instance using Windows-integrated context.

  .EXAMPLE
  Install-SqlServerInstance -DatabaseHost 'utat022' -SqlInstance 'QA' -Version '2022' -AuthenticationMode Mixed -CredentialsKey 'SQL_Testing_SA'
  Creates a named instance in mixed mode using Bitwarden credentials.

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines

  .LINK
  https://docs.dbatools.io/Install-DbaInstance
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Password retrieved from Bitwarden vault at runtime; not hardcoded plaintext')]
  [Alias('New-SqlServerInstance')]
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [Alias('HostName')]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('tcp', 'np', 'lpc')]
    [string]$ConnectionMethod = 'tcp',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Windows', 'Mixed')]
    [string]$AuthenticationMode = 'Windows',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$EngineCredentialSecretName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [System.Management.Automation.PSCredential]$EngineCredential,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Version = '2022',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Feature = 'Default',

    [Parameter(Mandatory = $false)]
    [string[]]$AdminAccount,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SqlServerSetupPath = 'D:\Temp\SQLExpr\extracted'
  )

  begin {
    $fn = 'Install-SqlServerInstance'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function Install-SqlServerInstance'

    try {
      if (-not (Get-Module -ListAvailable -Name dbatools)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message 'dbatools module not found. Installing for CurrentUser.'
        Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
      }
      Import-Module dbatools -ErrorAction Stop

      if (-not (Get-Command -Name 'Set-SqlServerSystemDatabaseTopology' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '..\private\Set-SqlServerSystemDatabaseTopology.ps1')
      }

      if ((-not [string]::IsNullOrWhiteSpace($CredentialsKey) -or -not [string]::IsNullOrWhiteSpace($EngineCredentialSecretName)) -and
        -not (Get-Command -Name 'Get-SecretATAP' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-SecretATAPBitwarden.ps1'
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-SecretATAP.ps1'
      }
    } catch {
      $errorMessage = "Failed loading dependencies. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  process {
    $requiredTopologyConfigRootKeys = @(
      'SqlInstanceTopologyConfigRootKey'
      'SqlInstanceTopologyHostsConfigRootKey'
      'SqlInstanceTopologyInstancesConfigRootKey'
      'SqlInstanceTopologyInstanceNameConfigRootKey'
      'SqlInstanceTopologyDataPathConfigRootKey'
      'SqlInstanceTopologyLogPathConfigRootKey'
      'SqlInstanceTopologyBackupPathConfigRootKey'
      'SqlInstanceTopologyTcpPortConfigRootKey'
    )
    $missingTopologyConfigRootKeys = @(
      $requiredTopologyConfigRootKeys | Where-Object {
        $null -eq $global:configRootKeys -or -not $global:configRootKeys.ContainsKey($_)
      }
    )
    if ($missingTopologyConfigRootKeys.Count -gt 0 -or $null -eq $global:settings) {
      $errorMessage = 'SQL instance topology is unavailable in $global:settings. Load the current ConfigRootKeys module and host settings before provisioning an instance.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    $settingsHostName = if ($DatabaseHost -in @('localhost', '.', '127.0.0.1')) {
      $env:COMPUTERNAME.ToLowerInvariant()
    } else {
      $DatabaseHost.ToLowerInvariant()
    }
    $topology = $global:settings[$global:configRootKeys['SqlInstanceTopologyConfigRootKey']]
    if ($null -eq $topology) {
      $errorMessage = 'SQL instance topology is unavailable in $global:settings. Load the current host settings before provisioning an instance.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
    $hostTopologies = $topology[$global:configRootKeys['SqlInstanceTopologyHostsConfigRootKey']]
    $hostTopology = $hostTopologies[$settingsHostName]
    if ($null -eq $hostTopology) {
      $errorMessage = "SQL instance topology does not contain host '$settingsHostName'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    $instances = $hostTopology[$global:configRootKeys['SqlInstanceTopologyInstancesConfigRootKey']]
    $instanceNameKey = $global:configRootKeys['SqlInstanceTopologyInstanceNameConfigRootKey']
    $topologyRows = @(
      $instances.Values | Where-Object { [string]$_[$instanceNameKey] -ieq $SqlInstance }
    )
    if ($topologyRows.Count -ne 1) {
      $errorMessage = "SQL instance topology must contain exactly one '$SqlInstance' row for host '$settingsHostName'; found $($topologyRows.Count)."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    $topologyRow = $topologyRows[0]
    $dataPath = [string]$topologyRow[$global:configRootKeys['SqlInstanceTopologyDataPathConfigRootKey']]
    $logPath = [string]$topologyRow[$global:configRootKeys['SqlInstanceTopologyLogPathConfigRootKey']]
    $backupPath = [string]$topologyRow[$global:configRootKeys['SqlInstanceTopologyBackupPathConfigRootKey']]
    $topologyPort = [int]$topologyRow[$global:configRootKeys['SqlInstanceTopologyTcpPortConfigRootKey']]
    $effectivePort = if ($PSBoundParameters.ContainsKey('Port')) { $Port } else { $topologyPort }
    if ([string]::IsNullOrWhiteSpace($dataPath) -or [string]::IsNullOrWhiteSpace($logPath) -or [string]::IsNullOrWhiteSpace($backupPath) -or $effectivePort -lt 1) {
      $errorMessage = "SQL instance topology row '$settingsHostName\$SqlInstance' must define DataPath, LogPath, BackupPath, and TcpPort."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    $targetInstanceName = if ([string]::IsNullOrWhiteSpace($SqlInstance) -or $SqlInstance -eq 'MSSQLSERVER') {
      $DatabaseHost
    } else {
      "$DatabaseHost\$SqlInstance"
    }

    # Default: Windows integrated security unless a CredentialsKey is explicitly supplied
    $useIntegratedSecurity = [string]::IsNullOrWhiteSpace($CredentialsKey)
    $vaultSecret = $null
    $saCredential = $null
    $resolvedEngineCredential = $EngineCredential

    if (-not $useIntegratedSecurity) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolving CredentialsKey '$CredentialsKey' from ATAP secret store."
        $saUserName = Get-SecretATAP -SecretName $CredentialsKey -SecretField 'username'
        $saPassword = Get-SecretATAP -SecretName $CredentialsKey -SecretField 'password'

        if ([string]::IsNullOrWhiteSpace($saUserName) -or [string]::IsNullOrWhiteSpace($saPassword)) {
          throw "Secret '$CredentialsKey' must expose both 'username' and 'password' fields."
        }

        $securePassword = ConvertTo-SecureString -String $saPassword -AsPlainText -Force
        $saCredential = New-Object System.Management.Automation.PSCredential($saUserName, $securePassword)
      } catch {
        $errorMessage = "Failed resolving credentials for key '$CredentialsKey'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    }

    if ($EngineCredential -and -not [string]::IsNullOrWhiteSpace($EngineCredentialSecretName)) {
      $errorMessage = 'Specify EngineCredential or EngineCredentialSecretName, not both.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    if (-not [string]::IsNullOrWhiteSpace($EngineCredentialSecretName)) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolving engine service credential by approved SecretName '$EngineCredentialSecretName'."
        $engineUserName = Get-SecretATAP -SecretName $EngineCredentialSecretName -SecretField 'username'
        $enginePassword = Get-SecretATAP -SecretName $EngineCredentialSecretName -SecretField 'password'
        if ([string]::IsNullOrWhiteSpace($engineUserName) -or [string]::IsNullOrWhiteSpace($enginePassword)) {
          throw "Secret '$EngineCredentialSecretName' must expose both 'username' and 'password' fields."
        }
        $engineSecurePassword = ConvertTo-SecureString -String $enginePassword -AsPlainText -Force
        $resolvedEngineCredential = [System.Management.Automation.PSCredential]::new($engineUserName, $engineSecurePassword)
      } catch {
        $errorMessage = "Failed resolving engine service credential '$EngineCredentialSecretName'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    }

    if ($effectivePort -and $ConnectionMethod -ne 'tcp') {
      $errorMessage = "Port may only be specified when ConnectionMethod is 'tcp'. ConnectionMethod is '$ConnectionMethod'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    if ($AuthenticationMode -eq 'Mixed' -and -not $saCredential) {
      $errorMessage = 'AuthenticationMode Mixed requires CredentialsKey that resolves to UserName/Password for SaCredential.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    $installParams = @{
      SqlInstance        = $targetInstanceName
      Version            = $Version
      Feature            = $Feature
      AuthenticationMode = $AuthenticationMode
      DataPath           = $dataPath
      LogPath            = $logPath
      BackupPath         = $backupPath
      TempPath           = $dataPath
      Configuration      = @{ SQLTEMPDBLOGDIR = $logPath }
      EnableException    = $true
    }

    if ($effectivePort) {
      $installParams['Port'] = $effectivePort
    }

    if ($AdminAccount -and $AdminAccount.Count -gt 0) {
      $installParams['AdminAccount'] = $AdminAccount
    }

    if ($AuthenticationMode -eq 'Mixed' -and $saCredential) {
      $installParams['SaCredential'] = $saCredential
    }
    if ($resolvedEngineCredential) {
      $installParams['EngineCredential'] = $resolvedEngineCredential
    }

    # Placeholder for future connection-string builder integration requested by design:
    # when CredentialsKey is supplied, IntegratedSecurity is disabled and SQL auth creds are used.
    # This cmdlet already tracks this behavior via $useIntegratedSecurity and vault-secret resolution.

    # Validate setup media path and configure dbatools — required even when SQL Server is
    # already installed; Install-DbaInstance always needs setup.exe + CAB files to add a
    # new named instance.
    if (-not (Test-Path -Path $SqlServerSetupPath -PathType Container)) {
      $errorMessage = "SQL Server setup media folder not found: '$SqlServerSetupPath'. Provide the path to the extracted setup media via -SqlServerSetupPath."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
    Set-DbatoolsConfig -Name 'Path.SQLServerSetup' -Value $SqlServerSetupPath
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Set dbatools Path.SQLServerSetup to '$SqlServerSetupPath'"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Prepared SQL Server installation for target '$targetInstanceName' using dbatools Install-DbaInstance."

    if ($PSCmdlet.ShouldProcess($targetInstanceName, 'Install SQL Server instance')) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Tag 'DbaToolsCall' -Message "Calling Install-DbaInstance for target $targetInstanceName"
        # Install-DbaInstance has ConfirmImpact=High and will prompt even when the caller
        # passes -Confirm:$false. Suppress by setting ConfirmPreference to None for this
        # scope so the prompt is never raised.
        $ConfirmPreference = 'None'
        $installResult = Install-DbaInstance @installParams -Confirm:$false
        $systemDatabaseTopology = Set-SqlServerSystemDatabaseTopology -DatabaseHost $DatabaseHost `
          -SqlInstance $SqlInstance -Port $effectivePort -DataPath $dataPath -LogPath $logPath -Confirm:$false
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Tag 'DbaToolsCall' -Message "Successfully returned from Install-DbaInstance for target $targetInstanceName"

        [PSCustomObject]@{
          DatabaseHost       = $DatabaseHost
          SqlInstance        = $SqlInstance
          TargetInstance     = $targetInstanceName
          ConnectionMethod   = $ConnectionMethod
          Port               = $effectivePort
          IntegratedSecurity = [bool]$useIntegratedSecurity
          CredentialsKey     = $CredentialsKey
          EngineCredentialSecretName = $EngineCredentialSecretName
          AuthenticationMode = $AuthenticationMode
          Feature            = $Feature
          Version            = $Version
          DataPath           = $dataPath
          LogPath            = $logPath
          BackupPath         = $backupPath
          InstallResult      = $installResult
          SystemDatabaseTopology = $systemDatabaseTopology
          Success            = $true
          TimestampUtc       = (Get-Date).ToUniversalTime()
        }
      } catch {
        $errorMessage = "Install-DbaInstance failed for '$targetInstanceName'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Installation of '$targetInstanceName' was cancelled by user."
      [PSCustomObject]@{
        DatabaseHost       = $DatabaseHost
        SqlInstance        = $SqlInstance
        TargetInstance     = $targetInstanceName
        ConnectionMethod   = $ConnectionMethod
        Port               = $effectivePort
        IntegratedSecurity = [bool]$useIntegratedSecurity
        CredentialsKey     = $CredentialsKey
        EngineCredentialSecretName = $EngineCredentialSecretName
        AuthenticationMode = $AuthenticationMode
        Feature            = $Feature
        Version            = $Version
        DataPath           = $dataPath
        LogPath            = $logPath
        BackupPath         = $backupPath
        InstallResult      = $null
        Success            = $false
        Cancelled          = $true
        TimestampUtc       = (Get-Date).ToUniversalTime()
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function Install-SqlServerInstance'
  }
}
