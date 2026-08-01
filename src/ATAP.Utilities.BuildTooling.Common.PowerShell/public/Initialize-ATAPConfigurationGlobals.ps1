function Initialize-ATAPConfigurationGlobals {
  <#
  .SYNOPSIS
    Ensures ATAP configuration globals are populated for the current process.
  .DESCRIPTION
    Bootstraps $global:configRootKeys and $global:settings when an agent shell
    did not inherit the workstation PowerShell profile state. The function
    loads Set-GlobalConfigRootKeys from ATAP.Utilities.ConfigRootKeys.PowerShell,
    then loads Get-HostSettings from ATAP.Utilities.Powershell and builds the
    host-specific settings hashtable.

    When RepositoryRoot points at an ATAP.Utilities worktree, the co-located
    source functions are preferred so sprint-start automation does not silently
    use stale installed copies. Otherwise the installed modules are imported.
  .PARAMETER RepositoryRoot
    Optional ATAP.Utilities repository or sprint-worktree root whose current
    source functions should be used.
  .PARAMETER IACBasePath
    Optional ATAP.IAC repository or sprint-worktree root forwarded to
    Get-HostSettings.
  .PARAMETER Force
    Rebuilds both globals even when they already contain the required database
    configuration.
  .OUTPUTS
    PSCustomObject describing whether initialization was required and the
    resulting collection sizes.
  .EXAMPLE
    Initialize-ATAPConfigurationGlobals
  .EXAMPLE
    Initialize-ATAPConfigurationGlobals -RepositoryRoot 'C:\src\ATAP.Utilities'
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'This bootstrap function exists specifically to populate the repository-standard global configuration hashtables.'
  )]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseSingularNouns',
    '',
    Justification = 'The function initializes both required configuration globals as one lifecycle operation.'
  )]
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [string]$RepositoryRoot,

    [Parameter()]
    [string]$IACBasePath,

    [Parameter()]
    [switch]$Force
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.Common.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    function Test-ATAPConfigurationGlobalsReady {
      $configReady = $global:configRootKeys -is [hashtable] -and
        $global:configRootKeys.Count -gt 0 -and
        -not [string]::IsNullOrWhiteSpace([string]$global:configRootKeys['DatabasesCollectionConfigRootKey'])

      if (-not $configReady -or -not ($global:settings -is [hashtable]) -or $global:settings.Count -eq 0) {
        return $false
      }

      $databasesCollectionKey = [string]$global:configRootKeys['DatabasesCollectionConfigRootKey']
      return $global:settings.ContainsKey($databasesCollectionKey)
    }

    function Resolve-ATAPConfigurationCommand {
      param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter()]
        [string]$SourcePath
      )

      if (-not [string]::IsNullOrWhiteSpace($SourcePath) -and
        (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        . $SourcePath
      } else {
        Import-Module -Name $ModuleName -Force -Global -ErrorAction Stop
      }

      $command = Get-Command -Name $CommandName -CommandType Function, Cmdlet -ErrorAction SilentlyContinue |
        Where-Object {
          [string]::IsNullOrWhiteSpace($SourcePath) -or
          [string]::Equals($_.ScriptBlock.File, $SourcePath, [System.StringComparison]::OrdinalIgnoreCase)
        } |
        Select-Object -First 1

      if ($null -eq $command) {
        $command = Get-Command -Name $CommandName -CommandType Function, Cmdlet -ErrorAction SilentlyContinue |
          Where-Object {
            [string]::Equals($_.ModuleName, $ModuleName, [System.StringComparison]::OrdinalIgnoreCase)
          } |
          Select-Object -First 1
      }

      if ($null -eq $command) {
        throw "Required configuration command '$CommandName' could not be loaded from '$ModuleName'."
      }

      return $command
    }

    $configRootKeysSourcePath = $null
    $hostSettingsSourcePath = $null
    if (-not [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
      $configRootKeysSourcePath = Join-Path $RepositoryRoot 'src\ATAP.Utilities.ConfigRootKeys.Powershell\public\Set-GlobalConfigRootKeys.ps1'
      $hostSettingsSourcePath = Join-Path $RepositoryRoot 'src\ATAP.Utilities.Powershell\public\Get-HostSettings.ps1'
    }
  }

  process {
    if (-not $Force -and (Test-ATAPConfigurationGlobalsReady)) {
      return [PSCustomObject]@{
        Initialized         = $false
        ConfigRootKeysCount = $global:configRootKeys.Count
        SettingsCount       = $global:settings.Count
        DatabaseSettingsKey = [string]$global:configRootKeys['DatabasesCollectionConfigRootKey']
      }
    }

    if (-not $PSCmdlet.ShouldProcess('$global:configRootKeys and $global:settings', 'Initialize ATAP configuration globals')) {
      return [PSCustomObject]@{
        Initialized         = $false
        ConfigRootKeysCount = 0
        SettingsCount       = 0
        DatabaseSettingsKey = $null
      }
    }

    try {
      $setConfigRootKeysCommand = Resolve-ATAPConfigurationCommand `
        -CommandName 'Set-GlobalConfigRootKeys' `
        -ModuleName 'ATAP.Utilities.ConfigRootKeys.PowerShell' `
        -SourcePath $configRootKeysSourcePath

      & $setConfigRootKeysCommand -Confirm:$false

      if ($null -eq $global:configRootKeys -or
        -not ($global:configRootKeys -is [hashtable]) -or
        [string]::IsNullOrWhiteSpace([string]$global:configRootKeys['DatabasesCollectionConfigRootKey'])) {
        throw 'Set-GlobalConfigRootKeys did not populate DatabasesCollectionConfigRootKey.'
      }

      $getHostSettingsCommand = Resolve-ATAPConfigurationCommand `
        -CommandName 'Get-HostSettings' `
        -ModuleName 'ATAP.Utilities.Powershell' `
        -SourcePath $hostSettingsSourcePath

      $hostName = if (-not [string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) {
        $env:COMPUTERNAME
      } else {
        [System.Net.Dns]::GetHostName()
      }

      $hostSettingsParameters = @{
        hostName = $hostName
        Confirm  = $false
      }
      if (-not [string]::IsNullOrWhiteSpace($IACBasePath)) {
        $hostSettingsParameters['IACBasePath'] = $IACBasePath
      }

      $global:settings = & $getHostSettingsCommand @hostSettingsParameters

      if (-not (Test-ATAPConfigurationGlobalsReady)) {
        $databasesCollectionKey = [string]$global:configRootKeys['DatabasesCollectionConfigRootKey']
        throw "Get-HostSettings did not populate the required '$databasesCollectionKey' settings collection."
      }

      if ($null -eq $global:PSDefaultParameterValues) {
        $global:PSDefaultParameterValues = @{}
      }
      $global:PSDefaultParameterValues['*:Settings'] = { $global:settings }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "ATAP configuration globals initialized for host '$hostName'."

      return [PSCustomObject]@{
        Initialized         = $true
        ConfigRootKeysCount = $global:configRootKeys.Count
        SettingsCount       = $global:settings.Count
        DatabaseSettingsKey = [string]$global:configRootKeys['DatabasesCollectionConfigRootKey']
      }
    } catch {
      $errorMessage = "Failed to initialize ATAP configuration globals. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
