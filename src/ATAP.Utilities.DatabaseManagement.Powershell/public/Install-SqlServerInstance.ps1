function Install-SqlServerInstance {
  <#
  .SYNOPSIS
  Creates a SQL Server instance on an existing SQL Server host.

  .DESCRIPTION
  Uses dbatools Install-DbaInstance to create/configure a SQL Server instance on a host
  where SQL Server software is already present.

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

      if (-not (Get-Command -Name 'Get-BitWardenSecret' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-BitWardenSecret.ps1'
      }
    } catch {
      $errorMessage = "Failed loading dependencies. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  process {
    $targetInstanceName = if ([string]::IsNullOrWhiteSpace($SqlInstance) -or $SqlInstance -eq 'MSSQLSERVER') {
      $DatabaseHost
    } else {
      "$DatabaseHost\$SqlInstance"
    }

    # Default: Windows integrated security unless a CredentialsKey is explicitly supplied
    $useIntegratedSecurity = [string]::IsNullOrWhiteSpace($CredentialsKey)
    $vaultSecret = $null
    $saCredential = $null

    if (-not $useIntegratedSecurity) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolving CredentialsKey '$CredentialsKey' from Bitwarden."
        $vaultSecret = Get-BitWardenSecret -SecretName $CredentialsKey

        if (-not $vaultSecret.UserName -or -not $vaultSecret.Password) {
          throw "Secret '$CredentialsKey' must contain UserName and Password properties."
        }

        $securePassword = ConvertTo-SecureString -String $vaultSecret.Password -AsPlainText -Force
        $saCredential = New-Object System.Management.Automation.PSCredential($vaultSecret.UserName, $securePassword)
      } catch {
        $errorMessage = "Failed resolving credentials for key '$CredentialsKey'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    }

    if ($Port -and $ConnectionMethod -ne 'tcp') {
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
      EnableException    = $true
    }

    if ($Port) {
      $installParams['Port'] = $Port
    }

    if ($AdminAccount -and $AdminAccount.Count -gt 0) {
      $installParams['AdminAccount'] = $AdminAccount
    }

    if ($AuthenticationMode -eq 'Mixed' -and $saCredential) {
      $installParams['SaCredential'] = $saCredential
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
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Tag 'DbaToolsCall' -Message "Successfully returned from Install-DbaInstance for target $targetInstanceName"

        [PSCustomObject]@{
          DatabaseHost       = $DatabaseHost
          SqlInstance        = $SqlInstance
          TargetInstance     = $targetInstanceName
          ConnectionMethod   = $ConnectionMethod
          Port               = $Port
          IntegratedSecurity = [bool]$useIntegratedSecurity
          CredentialsKey     = $CredentialsKey
          AuthenticationMode = $AuthenticationMode
          Feature            = $Feature
          Version            = $Version
          InstallResult      = $installResult
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
        Port               = $Port
        IntegratedSecurity = [bool]$useIntegratedSecurity
        CredentialsKey     = $CredentialsKey
        AuthenticationMode = $AuthenticationMode
        Feature            = $Feature
        Version            = $Version
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
