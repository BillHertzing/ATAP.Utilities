<#
.SYNOPSIS
  Returns all rule Kind definitions from ATAPUtilities.PrimitiveLanguageKind.
.DESCRIPTION
  Queries the PrimitiveLanguageKind table and returns a typed PSCustomObject for
  every Kind currently defined in the system. Used by the new-rule-kind skill as
  the first read step to understand the existing grammar landscape.
.PARAMETER DatabaseHost
  SQL Server host. Alias: HostName. Resolved from global:settings when omitted.
.PARAMETER Environment
  Target environment: Development, Testing, Production, or Experimental.
.PARAMETER SqlInstance
  Named SQL Server instance. Derived from Environment when omitted.
.PARAMETER DatabaseName
  Target database. Defaults to 'ATAPUtilitiesDB'.
.PARAMETER ConnectionMethod
  Protocol: tcp, np, lpc, or default.
.PARAMETER IntegratedSecurity
  Use Windows Integrated Authentication (default parameter set).
.PARAMETER CredentialsKey
  Bitwarden vault key for SQL credentials (CredentialsFromVault parameter set).
.OUTPUTS
  PSCustomObject[]  — each object: Id, KindName, LanguageName, Description, GrammarFilePath, PhiloteGUID
.EXAMPLE
  Get-RuleKinds -IntegratedSecurity
.EXAMPLE
  Get-RuleKinds -Environment 'Development' -IntegratedSecurity
.NOTES
  AI assisted using ./claude/Rules/Powershell.md as guidelines
  Private function: Get-RuleKindRows.ps1
.LINK
  https://github.com/whertzing/ATAP.Utilities
#>
function Get-RuleKinds {
  [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'IntegratedSecurity')]
  [OutputType([PSCustomObject[]])]
  param(
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [Alias('HostName')]
    [string] $DatabaseHost,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string] $Environment,

    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string] $SqlInstance,

    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string] $DatabaseName,

    [Parameter(Mandatory = $false, Position = 4, ValueFromPipelineByPropertyName = $true)]
    [string] $ConnectionMethod,

    [Parameter(Mandatory = $true, ParameterSetName = 'IntegratedSecurity')]
    [switch] $IntegratedSecurity,

    [Parameter(Mandatory = $true, ParameterSetName = 'CredentialsFromVault')]
    [string] $CredentialsKey
  )

  BEGIN {
    $fn = 'Get-RuleKinds'
    $mn = 'ATAP.Utilities.RulesManagement.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'New-ConnectionStringBuilderFromDbaTools' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\New-ConnectionStringBuilderFromDbaTools.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    $privateFunction = Join-Path $PSScriptRoot '..' 'private' 'Get-RuleKindRows.ps1'
    if (Test-Path $privateFunction) {
      . $privateFunction
    }
    else {
      $errorMessage = "Private function not found at: $privateFunction"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # Check and populate simple parameter
    $Environment = Get-PVal -ParameterName 'Environment' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.Environment' -DefaultValue 'Experimental' -AllowMissing:$true
    $validEnvironments = @('Development', 'Testing', 'Production', 'Experimental')
    if ($Environment -notin $validEnvironments) {
      throw "Invalid Environment '$Environment'. Must be one of: $($validEnvironments -join ', ')"
    }

    # Check and populate simple parameter
    $DatabaseHost = Get-PVal -ParameterName 'DatabaseHost' -originalPSBoundParameters $PSBoundParameters -dottedPath "RulesManagement.$Environment.DatabaseHost" -DefaultValue $DatabaseHost -AllowMissing:$true

    # Check and populate simple parameter as Type
    $sqlInstanceDefault = if ($Environment -eq 'Experimental') { $null } else { $Environment }
    $SqlInstance = Get-PVal -ParameterName 'SqlInstance' -originalPSBoundParameters $PSBoundParameters -dottedPath "RulesManagement.$Environment.SqlInstance" -DefaultValue $sqlInstanceDefault -AllowMissing:$true

    # Check and populate simple parameter
    $DatabaseName = Get-PVal -ParameterName 'DatabaseName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.DatabaseName' -DefaultValue 'ATAPUtilitiesDB' -AllowMissing:$true

    # Check and populate simple parameter
    $ConnectionMethod = Get-PVal -ParameterName 'ConnectionMethod' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.ConnectionMethod' -DefaultValue 'default' -AllowMissing:$true
    $validConnectionMethods = @('tcp', 'np', 'lpc', 'default')
    if ($ConnectionMethod -notin $validConnectionMethods) {
      throw "Invalid ConnectionMethod '$ConnectionMethod'. Must be one of: $($validConnectionMethods -join ', ')"
    }

    if ($PSCmdlet.ParameterSetName -eq 'CredentialsFromVault') {
      $CredentialsKey = Get-PVal -ParameterName 'CredentialsKey' -originalPSBoundParameters $PSBoundParameters -dottedPath "RulesManagement.$Environment.CredentialsKey" -DefaultValue $CredentialsKey -AllowMissing:$false
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'All parameters validated successfully'
  }

  PROCESS {
    $sqlConnection = $null
    try {
      $connBuilderParams = @{
        DatabaseName     = $DatabaseName
        ConnectionMethod = $ConnectionMethod
      }
      if (-not [string]::IsNullOrWhiteSpace($DatabaseHost)) { $connBuilderParams['DatabaseHost'] = $DatabaseHost }
      if (-not [string]::IsNullOrWhiteSpace($SqlInstance))  { $connBuilderParams['SqlInstance']  = $SqlInstance  }

      if ($PSCmdlet.ParameterSetName -eq 'IntegratedSecurity') {
        $connBuilderParams['IntegratedSecurity'] = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Using Windows Integrated Authentication'
      }
      else {
        $connBuilderParams['CredentialsKey'] = $CredentialsKey
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Using vault credentials with key: $CredentialsKey"
      }

      $connectionStringBuilder = New-ConnectionStringBuilderFromDbaTools @connBuilderParams
      $connectionString        = $connectionStringBuilder.ToString()
      $sqlConnection           = New-Object Microsoft.Data.SqlClient.SqlConnection($connectionString)
      $sqlConnection.Open()
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Database connection opened'

      if ($PSCmdlet.ShouldProcess($DatabaseName, 'Query PrimitiveLanguageKind')) {
        $result = Get-RuleKindRows -SqlConnection $sqlConnection
        return $result
      }
    }
    catch {
      $errorMessage = "Get-RuleKinds failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      # ToDo: accumulate the errors; potentially add to 'Problems'
      # ToDo: flesh out logging the stacktrace
      throw
    }
    finally {
      if ($sqlConnection) {
        if ($sqlConnection.State -eq [System.Data.ConnectionState]::Open) {
          $sqlConnection.Close()
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Database connection closed'
        }
        $sqlConnection.Dispose()
      }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}