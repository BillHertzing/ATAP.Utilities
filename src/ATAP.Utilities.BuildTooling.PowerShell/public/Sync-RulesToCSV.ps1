<#
.SYNOPSIS
Exports Rules, RulePrimitives, and related tables from the database to CSV files for version control.

.DESCRIPTION
Synchronizes database tables to CSV files in the Flyway Data directory, enabling version control
and backup of the Rules, Rule Primitives, Build Sets (RRSBS) system. Exports are organized by
language kind (CSharp, Powershell, SQL, MSBuild, Snippet, Path) and table type.

The function exports to the standard naming convention:
  - {Language}_RulePrimitives.csv
  - {Language}_Rules.csv
  - {Language}_Philote_Primitives.csv
  - {Language}_Philote_Rules.csv
  - {Language}_RuleSets.csv (Snippet only)
  - {Language}_Philote_RuleSets.csv (Snippet only)
  - {Language}_Instantiations.csv (Path only)
  - {Language}_InstantiationBindings.csv (Path only)

.PARAMETER DatabaseName
Name of the database to export from. Default: 'ATAPUtilities'.

.PARAMETER SqlInstance
SQL Server instance to connect to. Default: 'localhost'.

.PARAMETER OutputPath
Directory path where CSV files will be written. Default: Database/Flyway/Data relative to repository root.

.PARAMETER LanguageKind
Optional filter to export only specific language kinds. Valid values: 'CSharp', 'Powershell', 'SQL', 'MSBuild', 'Snippet', 'Path'.
If not specified, exports all languages.

.PARAMETER TableType
Optional filter to export only specific table types. Valid values: 'RulePrimitives', 'Rules', 'RuleSets', 'Instantiations'.
If not specified, exports all table types.

.PARAMETER UseIntegratedSecurity
Use Windows Integrated Security for authentication. Default: $true.

.PARAMETER Username
SQL Server username (only used if UseIntegratedSecurity is $false).

.PARAMETER Password
SQL Server password (only used if UseIntegratedSecurity is $false).

.PARAMETER Force
Overwrite existing CSV files without prompting.

.EXAMPLE
Sync-RulesToCSV

Exports all rules data to CSV files in the default Flyway Data directory.

.EXAMPLE
Sync-RulesToCSV -LanguageKind 'Powershell' -Force

Exports only PowerShell rules and primitives, overwriting existing files.

.EXAMPLE
Sync-RulesToCSV -OutputPath 'C:\Backup\Rules' -SqlInstance 'SQLSERVER01'

Exports all rules to a custom backup directory from a remote SQL Server.

.EXAMPLE
Sync-RulesToCSV -TableType 'Rules' -LanguageKind 'CSharp','SQL'

Exports only Rules (not primitives) for CSharp and SQL languages.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns an object with export statistics and file paths.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

Requires dbatools PowerShell module for database operations.
CSV files are UTF-8 encoded with quoted fields to match Flyway BULK INSERT requirements.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>

function Sync-RulesToCSV {
  [CmdletBinding(DefaultParameterSetName = 'ConnectionParts', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [AllowNull()]
    [object]$SqlConnection,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'BitwardenSecretName')]
    [Alias('BitwardenSecret', 'SecretName')]
    [string]$BitwardenSecretName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('HostName', 'ServerInstance')]
    [string]$DatabaseHost = 'localhost',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$InstanceName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'BitwardenSecretName')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$DatabaseName = 'ATAPUtilities',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('UseIntegratedSecurity')]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [switch]$UseTrustedConnection,

    [Parameter(Mandatory = $false)]
    [hashtable]$Settings,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('CSharp', 'Powershell', 'SQL', 'MSBuild', 'Snippet', 'Path')]
    [string[]]$LanguageKind,

    [Parameter(Mandatory = $false)]
    [ValidateSet('RulePrimitives', 'Rules', 'RuleSets', 'Instantiations')]
    [string[]]$TableType,

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [SecureString]$Password,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  BEGIN {
    $fn = 'Sync-RulesToCSV'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Get-Command -Name 'Resolve-BuildToolingDatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue) -or
      -not (Get-Command -Name 'Invoke-BuildToolingSqlQuery' -CommandType Function -ErrorAction SilentlyContinue)) {
      $helperPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'private\BuildToolingSql.Helpers.ps1'
      if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
        . $helperPath
      }
    }

    $integratedSecurityValue = if ($PSBoundParameters.ContainsKey('IntegratedSecurity')) { [bool]$IntegratedSecurity } else { $true }
    $resolvedSqlConnection = Resolve-BuildToolingDatabaseSqlConnection `
      -OriginalPSBoundParameters $PSBoundParameters `
      -SqlConnection $SqlConnection `
      -BitwardenSecretName $BitwardenSecretName `
      -DatabaseHost $DatabaseHost `
      -SqlInstance $SqlInstance `
      -InstanceName $InstanceName `
      -DatabaseName $DatabaseName `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -ApplicationName $ApplicationName `
      -UseTrustedConnection:$UseTrustedConnection `
      -IntegratedSecurity:$integratedSecurityValue `
      -Settings $Settings `
      -DefaultDatabaseHost 'localhost' `
      -DefaultDatabaseName 'ATAPUtilities'

    # Load Get-RepositoryRoot if needed
    if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
      $getRepoRootPath = Join-Path $PSScriptRoot 'Get-RepositoryRoot.ps1'
      if (Test-Path $getRepoRootPath) {
        . $getRepoRootPath
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loaded Get-RepositoryRoot from: $getRepoRootPath"
      }
    }

    # Determine output path
    if ([string]::IsNullOrEmpty($OutputPath)) {
      try {
        $repoRoot = Get-RepositoryRoot -StartPath $PSScriptRoot
        if ($repoRoot) {
          $OutputPath = Join-Path $repoRoot 'Database\Flyway\Data'
        }
        else {
          $OutputPath = Join-Path (Get-Location) 'Database\Flyway\Data'
        }
      }
      catch {
        $OutputPath = Join-Path (Get-Location) 'Database\Flyway\Data'
      }
    }

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Creating output directory: $OutputPath"
      New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Database: $DatabaseName"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SQL Instance: $($resolvedSqlConnection.DataSource)"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Output Path: $OutputPath"

    # Define language kinds to export
    $languageKinds = if ($LanguageKind) { $LanguageKind } else { @('CSharp', 'Powershell', 'SQL', 'MSBuild', 'Snippet', 'Path') }
    $tableTypes = if ($TableType) { $TableType } else { @('RulePrimitives', 'Rules', 'RuleSets', 'Instantiations') }

    # Initialize statistics
    $stats = @{
      ExportedFiles    = @()
      TotalRows        = 0
      Errors           = @()
      SkippedFiles     = @()
      StartTime        = Get-Date
    }
  }

  PROCESS {
    try {
      # Export data for each language kind
      foreach ($lang in $languageKinds) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Processing language: $lang"

        # Get PrimitiveLanguageKindId for this language
        $langIdQuery = "SELECT PrimitiveLanguageKindId FROM dbo.PrimitiveLanguageKind WHERE Name = '$lang'"
        $langId = Invoke-BuildToolingSqlQuery -SqlConnection $resolvedSqlConnection -Query $langIdQuery -As Scalar

        if ($null -eq $langId -or [DBNull]::Value -eq $langId) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Language kind '$lang' not found in database. Skipping."
          continue
        }

        # Export RulePrimitives
        if ($tableTypes -contains 'RulePrimitives') {
          $philotePrimFile = Join-Path $OutputPath "${lang}_Philote_Primitives.csv"
          $rulePrimFile = Join-Path $OutputPath "${lang}_RulePrimitives.csv"

          # Export Philote entries for primitives
          $philotePrimQuery = @"
SELECT p.PhiloteId, p.Comment
FROM dbo.Philote p
INNER JOIN dbo.RulePrimitive rp ON p.PhiloteId = rp.PhiloteId
WHERE rp.PrimitiveLanguageKindId = $langId
ORDER BY p.Comment
"@

          # Export RulePrimitive entries
          $rulePrimQuery = @"
SELECT PhiloteId, PrimitiveLanguageKindId, Name, Description
FROM dbo.RulePrimitive
WHERE PrimitiveLanguageKindId = $langId
ORDER BY Name
"@

          if ($PSCmdlet.ShouldProcess($philotePrimFile, 'Export Philote Primitives')) {
            $philotePrimData = Invoke-BuildToolingSqlQuery -SqlConnection $resolvedSqlConnection -Query $philotePrimQuery -As DataTable
            if ($philotePrimData.Rows.Count -gt 0) {
              $philotePrimData.Rows | Export-Csv -Path $philotePrimFile -NoTypeInformation -Encoding UTF8 -Force:$Force
              $stats.ExportedFiles += $philotePrimFile
              $stats.TotalRows += $philotePrimData.Rows.Count
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Exported $($philotePrimData.Rows.Count) rows to $philotePrimFile"
            }
            else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No RulePrimitive Philotes found for $lang"
              $stats.SkippedFiles += $philotePrimFile
            }
          }

          if ($PSCmdlet.ShouldProcess($rulePrimFile, 'Export RulePrimitives')) {
            $rulePrimData = Invoke-BuildToolingSqlQuery -SqlConnection $resolvedSqlConnection -Query $rulePrimQuery -As DataTable
            if ($rulePrimData.Rows.Count -gt 0) {
              $rulePrimData.Rows | Export-Csv -Path $rulePrimFile -NoTypeInformation -Encoding UTF8 -Force:$Force
              $stats.ExportedFiles += $rulePrimFile
              $stats.TotalRows += $rulePrimData.Rows.Count
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Exported $($rulePrimData.Rows.Count) rows to $rulePrimFile"
            }
            else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No RulePrimitives found for $lang"
              $stats.SkippedFiles += $rulePrimFile
            }
          }
        }

        # Export Rules
        if ($tableTypes -contains 'Rules') {
          $philoteRuleFile = Join-Path $OutputPath "${lang}_Philote_Rules.csv"
          $ruleFile = Join-Path $OutputPath "${lang}_Rules.csv"

          # Export Philote entries for rules
          $philoteRuleQuery = @"
SELECT p.PhiloteId, p.Comment
FROM dbo.Philote p
INNER JOIN dbo.[Rule] r ON p.PhiloteId = r.PhiloteId
WHERE r.PrimitiveLanguageKindId = $langId
ORDER BY p.Comment
"@

          # Export Rule entries
          $ruleQuery = @"
SELECT PhiloteId, PrimitiveLanguageKindId, Name, Purpose, SourceFileReference
FROM dbo.[Rule]
WHERE PrimitiveLanguageKindId = $langId
ORDER BY Name
"@

          if ($PSCmdlet.ShouldProcess($philoteRuleFile, 'Export Philote Rules')) {
            $philoteRuleData = Invoke-BuildToolingSqlQuery -SqlConnection $resolvedSqlConnection -Query $philoteRuleQuery -As DataTable
            if ($philoteRuleData.Rows.Count -gt 0) {
              $philoteRuleData.Rows | Export-Csv -Path $philoteRuleFile -NoTypeInformation -Encoding UTF8 -Force:$Force
              $stats.ExportedFiles += $philoteRuleFile
              $stats.TotalRows += $philoteRuleData.Rows.Count
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Exported $($philoteRuleData.Rows.Count) rows to $philoteRuleFile"
            }
            else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No Rule Philotes found for $lang"
              $stats.SkippedFiles += $philoteRuleFile
            }
          }

          if ($PSCmdlet.ShouldProcess($ruleFile, 'Export Rules')) {
            $ruleData = Invoke-BuildToolingSqlQuery -SqlConnection $resolvedSqlConnection -Query $ruleQuery -As DataTable
            if ($ruleData.Rows.Count -gt 0) {
              $ruleData.Rows | Export-Csv -Path $ruleFile -NoTypeInformation -Encoding UTF8 -Force:$Force
              $stats.ExportedFiles += $ruleFile
              $stats.TotalRows += $ruleData.Rows.Count
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Exported $($ruleData.Rows.Count) rows to $ruleFile"
            }
            else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No Rules found for $lang"
              $stats.SkippedFiles += $ruleFile
            }
          }
        }

        # Export RuleSets (Snippet language only)
        if ($tableTypes -contains 'RuleSets' -and $lang -eq 'Snippet') {
          $philoteRuleSetFile = Join-Path $OutputPath "${lang}_Philote_RuleSets.csv"
          $ruleSetFile = Join-Path $OutputPath "${lang}_RuleSets.csv"

          # Export Philote entries for rule sets
          $philoteRuleSetQuery = @"
SELECT p.PhiloteId, p.Comment
FROM dbo.Philote p
INNER JOIN dbo.RuleSet rs ON p.PhiloteId = rs.PhiloteId
ORDER BY p.Comment
"@

          # Export RuleSet entries
          $ruleSetQuery = @"
SELECT PhiloteId, Name, Description
FROM dbo.RuleSet
ORDER BY Name
"@

          if ($PSCmdlet.ShouldProcess($philoteRuleSetFile, 'Export Philote RuleSets')) {
            $philoteRuleSetData = Invoke-BuildToolingSqlQuery -SqlConnection $resolvedSqlConnection -Query $philoteRuleSetQuery -As DataTable
            if ($philoteRuleSetData.Rows.Count -gt 0) {
              $philoteRuleSetData.Rows | Export-Csv -Path $philoteRuleSetFile -NoTypeInformation -Encoding UTF8 -Force:$Force
              $stats.ExportedFiles += $philoteRuleSetFile
              $stats.TotalRows += $philoteRuleSetData.Rows.Count
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Exported $($philoteRuleSetData.Rows.Count) rows to $philoteRuleSetFile"
            }
          }

          if ($PSCmdlet.ShouldProcess($ruleSetFile, 'Export RuleSets')) {
            $ruleSetData = Invoke-BuildToolingSqlQuery -SqlConnection $resolvedSqlConnection -Query $ruleSetQuery -As DataTable
            if ($ruleSetData.Rows.Count -gt 0) {
              $ruleSetData.Rows | Export-Csv -Path $ruleSetFile -NoTypeInformation -Encoding UTF8 -Force:$Force
              $stats.ExportedFiles += $ruleSetFile
              $stats.TotalRows += $ruleSetData.Rows.Count
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Exported $($ruleSetData.Rows.Count) rows to $ruleSetFile"
            }
          }
        }

        # Export Instantiations (Path language only)
        if ($tableTypes -contains 'Instantiations' -and $lang -eq 'Path') {
          $philoteInstFile = Join-Path $OutputPath "${lang}_Philote_Instantiations.csv"
          $instFile = Join-Path $OutputPath "${lang}_Instantiations.csv"
          $bindFile = Join-Path $OutputPath "${lang}_InstantiationBindings.csv"

          # Export Philote entries for instantiations
          $philoteInstQuery = @"
SELECT p.PhiloteId, p.Comment
FROM dbo.Philote p
INNER JOIN dbo.RuleInstantiation ri ON p.PhiloteId = ri.PhiloteId
ORDER BY p.Comment
"@

          # Export RuleInstantiation entries
          $instQuery = @"
SELECT PhiloteId, RulePhiloteId, Notes
FROM dbo.RuleInstantiation
ORDER BY RulePhiloteId
"@

          # Export RuleInstantiationBinding entries
          $bindQuery = @"
SELECT InstantiationPhiloteId, InputName, InputValue
FROM dbo.RuleInstantiationBinding
ORDER BY InstantiationPhiloteId, InputName
"@

          if ($PSCmdlet.ShouldProcess($philoteInstFile, 'Export Philote Instantiations')) {
            $philoteInstData = Invoke-BuildToolingSqlQuery -SqlConnection $resolvedSqlConnection -Query $philoteInstQuery -As DataTable
            if ($philoteInstData.Rows.Count -gt 0) {
              $philoteInstData.Rows | Export-Csv -Path $philoteInstFile -NoTypeInformation -Encoding UTF8 -Force:$Force
              $stats.ExportedFiles += $philoteInstFile
              $stats.TotalRows += $philoteInstData.Rows.Count
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Exported $($philoteInstData.Rows.Count) rows to $philoteInstFile"
            }
          }

          if ($PSCmdlet.ShouldProcess($instFile, 'Export Instantiations')) {
            $instData = Invoke-BuildToolingSqlQuery -SqlConnection $resolvedSqlConnection -Query $instQuery -As DataTable
            if ($instData.Rows.Count -gt 0) {
              $instData.Rows | Export-Csv -Path $instFile -NoTypeInformation -Encoding UTF8 -Force:$Force
              $stats.ExportedFiles += $instFile
              $stats.TotalRows += $instData.Rows.Count
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Exported $($instData.Rows.Count) rows to $instFile"
            }
          }

          if ($PSCmdlet.ShouldProcess($bindFile, 'Export Instantiation Bindings')) {
            $bindData = Invoke-BuildToolingSqlQuery -SqlConnection $resolvedSqlConnection -Query $bindQuery -As DataTable
            if ($bindData.Rows.Count -gt 0) {
              $bindData.Rows | Export-Csv -Path $bindFile -NoTypeInformation -Encoding UTF8 -Force:$Force
              $stats.ExportedFiles += $bindFile
              $stats.TotalRows += $bindData.Rows.Count
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Exported $($bindData.Rows.Count) rows to $bindFile"
            }
          }
        }
      }

      # Calculate duration
      $stats.EndTime = Get-Date
      $stats.Duration = $stats.EndTime - $stats.StartTime

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Export completed: $($stats.ExportedFiles.Count) files, $($stats.TotalRows) total rows in $($stats.Duration.TotalSeconds) seconds"
    }
    catch {
      $errorMessage = "Export failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $stats.Errors += $errorMessage
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
  }

  END {
    # Return statistics object
    return [PSCustomObject]@{
      Success       = ($stats.Errors.Count -eq 0)
      ExportedFiles = $stats.ExportedFiles
      SkippedFiles  = $stats.SkippedFiles
      TotalRows     = $stats.TotalRows
      Duration      = $stats.Duration
      Errors        = $stats.Errors
      OutputPath    = $OutputPath
    }
  }
}
