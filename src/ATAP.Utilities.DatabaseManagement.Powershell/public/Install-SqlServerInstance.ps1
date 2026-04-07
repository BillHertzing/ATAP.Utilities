function Install-SqlServerInstance {
  <#
  .SYNOPSIS
  Creates a SQL Server instance on an existing SQL Server host.

  .DESCRIPTION
  Uses dbatools Install-DbaInstance to create/configure a SQL Server instance on a host
  where SQL Server software is already present.

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
  Examples: '16.0', '2022', '15.0', '2019'.

  .PARAMETER Feature
  Feature set passed to dbatools. Default: 'Default'.

  .PARAMETER AuthenticationMode
  SQL Server authentication mode: 'Windows' or 'Mixed'.

  .PARAMETER AdminAccount
  Optional sysadmin account(s) to assign.

  .OUTPUTS
  PSCustomObject containing request metadata and dbatools output.

  .EXAMPLE
  Install-SqlServerInstance -DatabaseHost 'localhost' -SqlInstance 'Development' -Version '16.0' -IntegratedSecurity
  Creates a named instance using Windows-integrated context.

  .EXAMPLE
  Install-SqlServerInstance -DatabaseHost 'utat022' -SqlInstance 'Testing' -Version '2022' -AuthenticationMode Mixed -CredentialsKey 'SQL_Testing_SA'
  Creates a named instance in mixed mode using Bitwarden credentials.

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines

  .LINK
  https://docs.dbatools.io/Install-DbaInstance
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [Alias('New-SqlServerInstance')]
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Version = '16.0',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Feature = 'Default',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Windows', 'Mixed')]
    [string]$AuthenticationMode = 'Windows',

    [Parameter(Mandatory = $false)]
    [string[]]$AdminAccount
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

    $useIntegratedSecurity = $true
    $vaultSecret = $null
    $saCredential = $null

    if (-not [string]::IsNullOrWhiteSpace($CredentialsKey)) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolving CredentialsKey '$CredentialsKey' from Bitwarden."
        $vaultSecret = Get-BitWardenSecret -SecretName $CredentialsKey

        if (-not $vaultSecret.UserName -or -not $vaultSecret.Password) {
          throw "Secret '$CredentialsKey' must contain UserName and Password properties."
        }

        $securePassword = ConvertTo-SecureString -String $vaultSecret.Password -AsPlainText -Force
        $saCredential = New-Object System.Management.Automation.PSCredential($vaultSecret.UserName, $securePassword)
        $useIntegratedSecurity = $false
      } catch {
        $errorMessage = "Failed resolving credentials for key '$CredentialsKey'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    } elseif (-not $IntegratedSecurity.IsPresent) {
      $IntegratedSecurity = $true
      $useIntegratedSecurity = $true
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

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Prepared SQL Server installation for target '$targetInstanceName' using dbatools Install-DbaInstance."

    if ($PSCmdlet.ShouldProcess($targetInstanceName, 'Install SQL Server instance')) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Tag 'DbaToolsCall' -Message "Calling Install-DbaInstance for target $targetInstanceName"
        $installResult = Install-DbaInstance @installParams
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
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function Install-SqlServerInstance'
  }
}
