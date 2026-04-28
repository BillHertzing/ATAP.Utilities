function New-SprintDatabaseInstances {
  <#
  .SYNOPSIS
    Creates the SQL Server database instance for the sprint's ephemeral
    experimental/development environment.
  .DESCRIPTION
    Calls Install-SqlServerInstance to create a single named SQL Server
    instance for the sprint. The instance name follows the convention:
      Sprint<NNNN>_<username>

    This single instance serves both the experimental (T1) and development
    (T2) tiers during the sprint lifetime.

    Requires Install-SqlServerInstance to be available (dot-sourced from
    ATAP.Utilities.DatabaseManagement.Powershell).
  .PARAMETER SprintNumber
    The sprint number (e.g., '0005').
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER Username
    The current user's name, used in the Development instance name.
  .PARAMETER DatabaseHost
    Host address for the SQL Server instances.
  .PARAMETER ConnectionMethod
    Connection protocol: 'tcp', 'namedpipe', or 'sharedmemory'.
  .PARAMETER Port
    Optional port number for the SQL Server instances. Pass $null to omit.
  .OUTPUTS
    Array of PSCustomObjects with instanceName, environment, databaseHost, created, and error fields.
  .EXAMPLE
    New-SprintDatabaseInstances -SprintNumber '0005' -GitRoot 'C:\Dropbox\whertzing\GitHub' `
      -Username 'whertzing' -DatabaseHost 'localhost' -ConnectionMethod 'tcp'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
    TODO: Validate Install-SqlServerInstance parameter names against the
          actual cmdlet definition in DatabaseManagement.Powershell.
  .LINK
    New-SprintStage2
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SprintNumber,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$GitRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseHost,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ConnectionMethod,

    [string]$Port
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Dot-source Install-SqlServerInstance if not already loaded
    if (-not (Get-Command -Name 'Install-SqlServerInstance' -CommandType Function -ErrorAction SilentlyContinue)) {
      # Try the sprint worktree path first, then fall back to the main repo path
      $candidates = @(
        (Get-ChildItem -Path $GitRoot -Directory -Filter 'ATAP.Utilities-wt-*' |
          Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName)
        (Join-Path $GitRoot 'ATAP.Utilities')
      )

      $loaded = $false
      foreach ($base in $candidates) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }
        $installPath = Join-Path $base 'src' 'ATAP.Utilities.DatabaseManagement.Powershell' 'public' 'Install-SqlServerInstance.ps1'
        if (Test-Path $installPath) {
          . $installPath
          $loaded = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Loaded Install-SqlServerInstance from $installPath"
          break
        }
      }

      if (-not $loaded) {
        throw 'Install-SqlServerInstance.ps1 not found. Cannot create sprint database instances.'
      }
    }
  }

  process {
    $instancesToCreate = @(
      @{ InstanceName = "Sprint${SprintNumber}_${Username}"; Environment = "Sprint${SprintNumber}_${Username}" }
    )

    $results = [System.Collections.ArrayList]::new()

    foreach ($inst in $instancesToCreate) {
      $instanceName = $inst.InstanceName
      $envLabel = $inst.Environment

      $entry = [PSCustomObject]@{
        instanceName = $instanceName
        environment  = $envLabel
        databaseHost = $DatabaseHost
        created      = $false
        error        = $null
      }

      $installParams = @{
        SQLInstance      = $instanceName
        DatabaseHost     = $DatabaseHost
        ConnectionMethod = $ConnectionMethod
      }

      if (-not [string]::IsNullOrWhiteSpace($Port)) {
        $installParams['Port'] = $Port
      }

      if ($PSCmdlet.ShouldProcess($instanceName, 'Install SQL Server instance')) {
        try {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
            -Message "Creating SQL instance: $instanceName on $DatabaseHost"

          Install-SqlServerInstance @installParams

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "SQL instance created: $instanceName"
          $entry.created = $true
        } catch {
          $errMsg = "Failed to create SQL instance '$instanceName'. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
          $entry.error = $errMsg
        }
      }

      [void]$results.Add($entry)
    }

    return $results.ToArray()
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
