function Get-DatabaseCredentialsKey {
  <#
  .SYNOPSIS
  Constructs the Bitwarden secret name for a database connection string.

  .DESCRIPTION
  Returns the canonical Bitwarden secure-note item name for the connection
  string secret that corresponds to a given (DatabaseName, DatabaseHost,
  Environment) tuple, following the ecosystem naming scheme:

    Permanent tiers (Production, QA, Integration):
      dbConnectionString.<DatabaseName>.<DatabaseHost>.<Environment>

    Per-sprint tiers (Development/Dev, Experimental/Exp):
      dbConnectionString.<DatabaseName>.<DatabaseHost>.<Environment>.<UserName>

  The returned string is suitable for use as the -SecretName argument to
  Get-SecretATAP, or as the CredentialsKey setting value in
  $global:settings['DatabasesCollection'].

  NOTE: Integration, QA, and Production databases reside on dedicated
  ecosystem SQL Server instances (named Integration, QA, Production
  respectively) running on shared infrastructure hosts — NOT on the
  developer workstation. Development and Experimental instances are
  per-sprint instances on the developer workstation (named Development
  and Experimental). Connection strings for Development and Experimental
  are scoped to the individual developer ($UserName) and are created at
  sprint start and deleted at sprint end.

  .PARAMETER DatabaseName
  The logical database name. Examples: 'ATAPUtilities', 'AceCommander'.

  .PARAMETER DatabaseHost
  The SQL Server host name. Use 'localhost' or the machine's hostname.

  .PARAMETER Environment
  The deployment tier. One of: Production, QA, Integration, Development,
  Experimental, Dev, Exp.

  .PARAMETER UserName
  The developer's Windows username. Required for Development and
  Experimental tiers. Defaults to $env:USERNAME when not supplied.

  .OUTPUTS
  [string] The Bitwarden item name for the connection-string secret.

  .EXAMPLE
  Get-DatabaseCredentialsKey -DatabaseName 'ATAPUtilities' -DatabaseHost 'localhost' -Environment 'Development'
  # Returns: dbConnectionString.ATAPUtilities.localhost.Dev.<current username>

  .EXAMPLE
  Get-DatabaseCredentialsKey -DatabaseName 'AceCommander' -DatabaseHost 'sqlserver01' -Environment 'Production'
  # Returns: dbConnectionString.AceCommander.sqlserver01.Production

  .EXAMPLE
  Get-DatabaseCredentialsKey -DatabaseName 'ATAPUtilities' -DatabaseHost 'localhost' -Environment 'Experimental' -UserName 'jsmith'
  # Returns: dbConnectionString.ATAPUtilities.localhost.Exp.jsmith

  .NOTES
  Naming scheme defined in 5TierRemainingTasks.md §6 and §4.3.
  Permanent secrets are created once per workstation during onboarding via
  New-PermanentBitwardenSecrets. Per-sprint secrets are created by
  New-SprintBitwardenSecrets at sprint start and removed by
  Remove-SprintBitwardenSecrets at sprint end.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $DatabaseName,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $DatabaseHost,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('Production', 'QA', 'Integration', 'Development', 'Experimental', 'Dev', 'Exp')]
    [string] $Environment,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $UserName
  )

  process {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName

    $tierToken = switch ($Environment) {
      'Development' { 'Dev' }
      'Dev' { 'Dev' }
      'Experimental' { 'Exp' }
      'Exp' { 'Exp' }
      default { $Environment }
    }

    $sprintTiers = @('Dev', 'Exp')
    $isSprintTier = $tierToken -in $sprintTiers

    if ($isSprintTier) {
      # Per-sprint secret: include developer username
      if ([string]::IsNullOrWhiteSpace($UserName)) {
        $UserName = $env:USERNAME
      }
      $key = "dbConnectionString.$DatabaseName.$DatabaseHost.$tierToken.$UserName"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Computed per-sprint CredentialsKey: $key" -Tag 'ConnectionString'
    } else {
      # Permanent secret: no username suffix
      $key = "dbConnectionString.$DatabaseName.$DatabaseHost.$tierToken"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Computed permanent CredentialsKey: $key" -Tag 'ConnectionString'
    }

    return $key
  }
}
