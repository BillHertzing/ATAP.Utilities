function Read-SourceAndCreateRules {
  <#
.SYNOPSIS
Reads source code files and creates Rules entries by parsing metadata from code structure and comments.

.DESCRIPTION
AI-assisted extraction of Rules, Rule Primitives, and Build Sets (RRSBS) metadata from source code files.
Supports PowerShell (.ps1), C# (.cs), MSBuild (.csproj), and SQL (.sql) files. Parses function/class
declarations, comment-based help, and file structure to generate Rules entries with unique PhiloteIds.

The function can write directly to CSV files (for version control) or to the database, or both.
Interactive mode allows review and editing of extracted metadata before committing.

Extracted metadata includes:
  - PhiloteId (generated GUID)
  - Name (function/class/file name)
  - Purpose (extracted from .SYNOPSIS, /// <summary>, or -- comments)
  - SourceFileReference (relative path from repository root)
  - PrimitiveLanguageKindId (determined from file extension)

.PARAMETER SourceFiles
Array of source file paths to parse. Accepts wildcards and pipeline input.

.PARAMETER SourceDirectory
Directory path to recursively search for source files. Filters by -FileExtension parameter.

.PARAMETER FileExtension
File extensions to process when using -SourceDirectory. Default: @('.ps1', '.cs', '.csproj', '.sql').

.PARAMETER LanguageKind
Override automatic language detection. Valid values: 'CSharp', 'Powershell', 'SQL', 'MSBuild'.
If not specified, determines language from file extension.

.PARAMETER OutputPath
Directory path for CSV output files. Default: Database/Flyway/Data relative to repository root.

.PARAMETER WriteToDatabase
Write extracted rules directly to the database in addition to CSV files.

.PARAMETER DatabaseName
Name of the database when using -WriteToDatabase. Default: 'ATAPUtilities'.

.PARAMETER SqlInstance
SQL Server instance when using -WriteToDatabase. Default: 'localhost'.

.PARAMETER Interactive
Enable interactive mode to review and edit extracted metadata before writing.

.PARAMETER SkipCSV
Skip writing to CSV files (only write to database when -WriteToDatabase is specified).

.PARAMETER Force
Overwrite existing CSV files or database entries without prompting.

.PARAMETER ExcludePattern
Regex pattern to exclude files from processing (e.g., '.*\.Tests\.ps1$' to skip test files).

.EXAMPLE
Read-SourceAndCreateRules -SourceFiles 'src\ATAP.Utilities.BuildTooling.PowerShell\public\*.ps1' -Interactive

Parses all PowerShell cmdlets in the public directory with interactive review.

.EXAMPLE
Get-ChildItem 'src\*.cs' -Recurse | Read-SourceAndCreateRules -WriteToDatabase

Parses all C# files recursively and writes to both CSV and database.

.EXAMPLE
Read-SourceAndCreateRules -SourceDirectory 'src\ATAP.Utilities.Philote' -FileExtension '.cs' -LanguageKind 'CSharp'

Parses all C# files in the Philote directory and creates CSharp rules.

.EXAMPLE
Read-SourceAndCreateRules -SourceFiles 'Database\Flyway\SQL\*.sql' -Force

Parses SQL migration scripts and overwrites existing CSV entries.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns an object with parsing statistics and created rules.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

Requires PowerShell 7+ for cross-platform AST parsing.
For C# parsing, uses basic regex patterns (Roslyn integration future enhancement).
Generated PhiloteIds are deterministic based on file path hash to support idempotent runs.

.LINK
https://github.com/whertzing/ATAP.Utilities

#>

  [CmdletBinding(DefaultParameterSetName = 'ConnectionParts', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('Path', 'FullName')]
    [ValidateNotNullOrEmpty()]
    [string[]]$SourceFiles,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDirectory,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$FileExtension = @('.ps1', '.cs', '.csproj', '.sql'),

    [Parameter(Mandatory = $false)]
    [ValidateSet('CSharp', 'Powershell', 'SQL', 'MSBuild')]
    [string]$LanguageKind,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$WriteToDatabase,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [AllowNull()]
    [object]$SqlConnection,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'DBConnectionStringSecretName')]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string]$DBConnectionStringSecretName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('HostName', 'ServerInstance')]
    [string]$DatabaseHost = 'localhost',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$InstanceName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'DBConnectionStringSecretName')]
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
    [switch]$Interactive,

    [Parameter(Mandatory = $false)]
    [switch]$SkipCSV,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [string]$ExcludePattern
  )

  BEGIN {
    $fn = 'Read-SourceAndCreateRules'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    try {
      if ($SourceFiles -and $SourceDirectory) {
        throw 'Specify SourceFiles or SourceDirectory, not both.'
      }

      if (-not $SourceFiles -and [string]::IsNullOrWhiteSpace($SourceDirectory) -and -not $MyInvocation.ExpectingInput) {
        throw 'Specify SourceFiles, SourceDirectory, or provide source files through the pipeline.'
      }

      # Load Get-RepositoryRoot if needed
      if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1'
      }

    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errorMessage
      throw
    }


    # Handle $PSScriptRoot being null (e.g., when running from debugger or dot-sourced)
    $scriptRoot = if ([string]::IsNullOrEmpty($PSScriptRoot)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message '$PSScriptRoot is null/empty (debugger or dot-sourced), using current location'
      (Get-Location).Path
    }
    else {
      $PSScriptRoot
    }

    if ($WriteToDatabase) {
      if (-not (Get-Command -Name 'Resolve-BuildToolingDatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue) -or
        -not (Get-Command -Name 'Invoke-BuildToolingSqlQuery' -CommandType Function -ErrorAction SilentlyContinue)) {
        $helperPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'private\BuildToolingSql.Helpers.ps1'
        if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
          . $helperPath
        }
      }

      $integratedSecurityValue = if ($PSBoundParameters.ContainsKey('IntegratedSecurity')) { [bool]$IntegratedSecurity } else { $true }
      $resolution = Resolve-BuildToolingDatabaseSqlConnection `
        -OriginalPSBoundParameters $PSBoundParameters `
        -SqlConnection $SqlConnection `
        -DBConnectionStringSecretName $DBConnectionStringSecretName `
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
      $openSQLConnection = $resolution.Connection
      $isCallerOwnedConnection = [bool]$resolution.IsCallerOwned
    }
    else {
      $openSQLConnection = $null
      $isCallerOwnedConnection = $false
    }
    # Get repository root for relative paths
    try {
      $repoRootRelative = Get-RepositoryRoot -StartPath $scriptRoot
      if ($repoRootRelative) {
        $repoRootCandidate = if ([System.IO.Path]::IsPathRooted($repoRootRelative)) {
          $repoRootRelative
        }
        else {
          Join-Path $scriptRoot $repoRootRelative
        }
        $script:repoRoot = Resolve-Path -Path $repoRootCandidate | Select-Object -ExpandProperty Path
      }
      else {
        $script:repoRoot = (Get-Location).Path
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Repository root (absolute): $script:repoRoot"
    }
    catch {
      $script:repoRoot = (Get-Location).Path
    }

    # Determine output path
    if ([string]::IsNullOrEmpty($OutputPath)) {
      $OutputPath = Join-Path $script:repoRoot 'Database\Flyway\Data'
    }

    # Ensure output directory exists
    if (-not $SkipCSV -and -not (Test-Path $OutputPath)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Creating output directory: $OutputPath"
      New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Get files from directory if specified
    if (-not [string]::IsNullOrWhiteSpace($SourceDirectory)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Scanning directory: $SourceDirectory"
      $SourceFiles = Get-ChildItem -Path $SourceDirectory -Recurse -Include $FileExtension | Select-Object -ExpandProperty FullName

      if ($ExcludePattern) {
        $SourceFiles = $SourceFiles | Where-Object { $_ -notmatch $ExcludePattern }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $($SourceFiles.Count) files to process"
    }

    # Language kind mapping
    $script:languageMap = @{
      '.ps1'     = 'Powershell'
      '.psm1'    = 'Powershell'
      '.psd1'    = 'Powershell'
      '.cs'      = 'CSharp'
      '.csproj'  = 'MSBuild'
      '.props'   = 'MSBuild'
      '.targets' = 'MSBuild'
      '.sql'     = 'SQL'
    }

    # Language kind ID mapping
    $script:languageIdMap = @{
      'CSharp'     = 1
      'Powershell' = 2
      'SQL'        = 3
      'MSBuild'    = 4
      'Snippet'    = 5
      'Path'       = 6
    }

    # Initialize collections
    $script:extractedRules = @()
    $script:extractedPhilotes = @()

    # Initialize statistics
    $stats = @{
      ProcessedFiles = 0
      ExtractedRules = 0
      SkippedFiles   = @()
      Errors         = @()
      StartTime      = Get-Date
    }
  }

  PROCESS {
    try {
      foreach ($file in $SourceFiles) {
        try {
          # Apply exclusion pattern
          if ($ExcludePattern -and $file -match $ExcludePattern) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Skipping excluded file: $file"
            $stats.SkippedFiles += $file
            continue
          }

          # Validate file exists
          if (-not (Test-Path $file)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "File not found: $file"
            $stats.SkippedFiles += $file
            continue
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Processing file: $file"

          # Determine language kind
          $fileExt = [System.IO.Path]::GetExtension($file)
          $detectedLang = if ($LanguageKind) { $LanguageKind } else { $script:languageMap[$fileExt] }

          if (-not $detectedLang) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Unknown file extension '$fileExt': $file"
            $stats.SkippedFiles += $file
            continue
          }

          $langId = $script:languageIdMap[$detectedLang]

          # Get relative path from repository root
          $relativePath = [System.IO.Path]::GetRelativePath($script:repoRoot, $file)
          $relativePath = $relativePath -replace '\\', '/'  # Normalize to forward slashes

          # Parse file based on language
          $extractedData = switch ($detectedLang) {
            'Powershell' { Parse-PowerShellFile -FilePath $file -RelativePath $relativePath }
            'CSharp' { Parse-CSharpFile -FilePath $file -RelativePath $relativePath }
            'MSBuild' { Parse-MSBuildFile -FilePath $file -RelativePath $relativePath }
            'SQL' { Parse-SQLFile -FilePath $file -RelativePath $relativePath }
            default {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Unsupported language: $detectedLang"
              $null
            }
          }

          if ($extractedData) {
            foreach ($item in $extractedData) {
              # Generate PhiloteId (deterministic based on file path and name)
              $seedString = "$relativePath::$($item.Name)"
              $philoteId = New-DeterministicGuid -SeedString $seedString

              # Create rule object
              $rule = [PSCustomObject]@{
                PhiloteId               = $philoteId
                PrimitiveLanguageKindId = $langId
                Name                    = $item.Name
                Purpose                 = $item.Purpose
                SourceFileReference     = $relativePath
                LanguageKind            = $detectedLang
              }

              # Create philote object
              $philote = [PSCustomObject]@{
                PhiloteId = $philoteId
                Comment   = $item.Name
              }

              $script:extractedRules += $rule
              $script:extractedPhilotes += $philote
              $stats.ExtractedRules++
            }
          }

          $stats.ProcessedFiles++
        }
        catch {
          $errorMessage = "Error processing file '$file': $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $stats.Errors += $errorMessage
        }
      }
    }
    catch {
      $errorMessage = "Fatal error in PROCESS block: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $stats.Errors += $errorMessage
      throw
    }
  }

  END {
    try {
      # Interactive review if requested
      if ($Interactive -and $script:extractedRules.Count -gt 0) {
        Write-Host "`n=== Extracted Rules Review ===" -ForegroundColor Cyan
        for ($i = 0; $i -lt $script:extractedRules.Count; $i++) {
          $rule = $script:extractedRules[$i]
          Write-Host "`n[$($i+1) of $($script:extractedRules.Count)] $($rule.Name)" -ForegroundColor Yellow
          Write-Host "  Language: $($rule.LanguageKind)"
          Write-Host "  Purpose:  $($rule.Purpose)"
          Write-Host "  Source:   $($rule.SourceFileReference)"
          Write-Host "  PhiloteId: $($rule.PhiloteId)"

          $action = Read-Host "`nAction: [K]eep, [E]dit, [S]kip, [Q]uit? (default: Keep)"

          switch ($action.ToUpper()) {
            'E' {
              $newPurpose = Read-Host "Enter new Purpose (current: $($rule.Purpose))"
              if (-not [string]::IsNullOrWhiteSpace($newPurpose)) {
                $rule.Purpose = $newPurpose
              }
            }
            'S' {
              $script:extractedRules[$i] = $null
              $script:extractedPhilotes[$i] = $null
            }
            'Q' {
              Write-Host "Quitting interactive review..." -ForegroundColor Yellow
              break
            }
          }
        }

        # Remove skipped items
        $script:extractedRules = $script:extractedRules | Where-Object { $null -ne $_ }
        $script:extractedPhilotes = $script:extractedPhilotes | Where-Object { $null -ne $_ }
      }

      # Group by language kind for CSV export
      if (-not $SkipCSV -and $script:extractedRules.Count -gt 0) {
        $groupedByLang = $script:extractedRules | Group-Object -Property LanguageKind

        foreach ($group in $groupedByLang) {
          $lang = $group.Name
          $rules = $group.Group

          # Export Rules CSV
          $ruleFile = Join-Path $OutputPath "${lang}_Rules.csv"
          $philoteRuleFile = Join-Path $OutputPath "${lang}_Philote_Rules.csv"

          # Read existing CSVs if they exist and not forcing overwrite
          $existingRules = @()
          $existingPhilotes = @()

          if (-not $Force) {
            if (Test-Path $ruleFile) {
              $existingRules = Import-Csv $ruleFile
            }
            if (Test-Path $philoteRuleFile) {
              $existingPhilotes = Import-Csv $philoteRuleFile
            }
          }

          # Merge new rules with existing (avoid duplicates by PhiloteId)
          $existingPhiloteIds = $existingRules | Select-Object -ExpandProperty PhiloteId
          $newRules = $rules | Where-Object { $_.PhiloteId -notin $existingPhiloteIds }

          if ($newRules) {
            $allRules = @($existingRules) + @($newRules | Select-Object PhiloteId, PrimitiveLanguageKindId, Name, Purpose, SourceFileReference)
            $allPhilotes = @($existingPhilotes) + @(
              $newRules | ForEach-Object {
                $philoteId = $_.PhiloteId
                $name = $_.Name
                [PSCustomObject]@{
                  PhiloteId = $philoteId
                  Comment   = $name
                }
              }
            )

            if ($PSCmdlet.ShouldProcess($ruleFile, "Export $($newRules.Count) new rules")) {
              $allRules | Export-Csv -Path $ruleFile -NoTypeInformation -Encoding UTF8 -Force
              $allPhilotes | Export-Csv -Path $philoteRuleFile -NoTypeInformation -Encoding UTF8 -Force
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Exported $($newRules.Count) new rules to $ruleFile"
            }
          }
          else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No new rules to export for $lang"
          }
        }
      }

      # Write to database if requested
      if ($WriteToDatabase -and $script:extractedRules.Count -gt 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Writing $($script:extractedRules.Count) rules to database..."

        foreach ($philote in $script:extractedPhilotes) {
          $insertPhiloteQuery = @"
IF NOT EXISTS (SELECT 1 FROM dbo.Philote WHERE PhiloteId = @PhiloteId)
BEGIN
  INSERT INTO dbo.Philote (PhiloteId, Comment)
  VALUES (@PhiloteId, @Comment)
END
"@
          Invoke-BuildToolingSqlQuery `
            -SqlConnection $openSQLConnection `
            -Query $insertPhiloteQuery `
            -Parameters @{
              PhiloteId = $philote.PhiloteId
              Comment   = $philote.Comment
            } `
            -As NonQuery | Out-Null
        }

        foreach ($rule in $script:extractedRules) {
          $insertRuleQuery = @"
IF NOT EXISTS (SELECT 1 FROM dbo.[Rule] WHERE PhiloteId = @PhiloteId)
BEGIN
  INSERT INTO dbo.[Rule] (PhiloteId, PrimitiveLanguageKindId, Name, Purpose, SourceFileReference)
  VALUES (@PhiloteId, @PrimitiveLanguageKindId, @Name, @Purpose, @SourceFileReference)
END
"@
          Invoke-BuildToolingSqlQuery `
            -SqlConnection $openSQLConnection `
            -Query $insertRuleQuery `
            -Parameters @{
              PhiloteId               = $rule.PhiloteId
              PrimitiveLanguageKindId = $rule.PrimitiveLanguageKindId
              Name                    = $rule.Name
              Purpose                 = $rule.Purpose
              SourceFileReference     = $rule.SourceFileReference
            } `
            -As NonQuery | Out-Null
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database write completed"
      }

      # Calculate duration
      $stats.EndTime = Get-Date
      $stats.Duration = $stats.EndTime - $stats.StartTime

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Processing completed: $($stats.ProcessedFiles) files, $($stats.ExtractedRules) rules in $($stats.Duration.TotalSeconds) seconds"
    }
    catch {
      $errorMessage = "Error in END block: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $stats.Errors += $errorMessage
      if ($null -ne $openSQLConnection) {
        try { $openSQLConnection.Close() } catch { }
        try { $openSQLConnection.Dispose() } catch { }
        $openSQLConnection = $null
      }
    }
    finally {
      if (-not $isCallerOwnedConnection -and $null -ne $openSQLConnection) {
        try { $openSQLConnection.Close() } catch { }
        try { $openSQLConnection.Dispose() } catch { }
        $openSQLConnection = $null
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }

    # Return statistics and extracted rules
    return [PSCustomObject]@{
      Success        = ($stats.Errors.Count -eq 0)
      ProcessedFiles = $stats.ProcessedFiles
      ExtractedRules = $stats.ExtractedRules
      SkippedFiles   = $stats.SkippedFiles
      Rules          = $script:extractedRules
      Duration       = $stats.Duration
      Errors         = $stats.Errors
      OutputPath     = $OutputPath
    }
  }
}

#region Helper Functions

function Parse-PowerShellFile {
  param(
    [string]$FilePath,
    [string]$RelativePath
  )

  try {
    $content = Get-Content -Path $FilePath -Raw
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)

    if ($errors.Count -gt 0) {
      Write-PSFMessage -Level Warning -Message "Parse errors in $FilePath : $($errors -join '; ')"
      return $null
    }

    $results = @()

    # Find function definitions
    $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    foreach ($func in $functions) {
      $funcName = $func.Name

      # Extract synopsis from comment-based help
      $helpContent = $func.GetHelpContent()
      $purpose = if ($helpContent.Synopsis) {
        $helpContent.Synopsis.Trim()
      }
      else {
        "PowerShell function $funcName"
      }

      $results += [PSCustomObject]@{
        Name    = $funcName
        Purpose = $purpose
      }
    }

    return $results
  }
  catch {
    Write-PSFMessage -Level Error -Message "Error parsing PowerShell file '$FilePath': $($_.Exception.Message)"
    return $null
  }
}

function Parse-CSharpFile {
  param(
    [string]$FilePath,
    [string]$RelativePath
  )

  try {
    $content = Get-Content -Path $FilePath -Raw

    # Basic regex parsing for classes and records (Roslyn integration would be better)
    $classPattern = '(?:public|internal|private|protected)\s+(?:static\s+)?(?:class|record|interface|struct)\s+(\w+)'
    $matches = [regex]::Matches($content, $classPattern)

    $results = @()
    foreach ($match in $matches) {
      $className = $match.Groups[1].Value

      # Try to extract XML summary comment
      $summaryPattern = "///\s+<summary>\s*\r?\n\s*///\s+(.*?)\r?\n\s*///\s+</summary>.*?$classPattern" -replace '\$classPattern', [regex]::Escape($className)
      $summaryMatch = [regex]::Match($content, $summaryPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

      $purpose = if ($summaryMatch.Success) {
        $summaryMatch.Groups[1].Value.Trim()
      }
      else {
        "C# type $className"
      }

      $results += [PSCustomObject]@{
        Name    = $className
        Purpose = $purpose
      }
    }

    return $results
  }
  catch {
    Write-PSFMessage -Level Error -Message "Error parsing C# file '$FilePath': $($_.Exception.Message)"
    return $null
  }
}

function Parse-SQLFile {
  param(
    [string]$FilePath,
    [string]$RelativePath
  )

  try {
    $content = Get-Content -Path $FilePath -Raw
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)

    # Look for comment header describing the script
    $purposePattern = '--\s+(.*?)(?:\r?\n--|\r?\n\r?\n)'
    $match = [regex]::Match($content, $purposePattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)

    $purpose = if ($match.Success) {
      $match.Groups[1].Value.Trim()
    }
    else {
      "SQL script $fileName"
    }

    return @(
      [PSCustomObject]@{
        Name    = $fileName
        Purpose = $purpose
      }
    )
  }
  catch {
    Write-PSFMessage -Level Error -Message "Error parsing SQL file '$FilePath': $($_.Exception.Message)"
    return $null
  }
}

function New-DeterministicGuid {
  param([string]$SeedString)

  # Create deterministic GUID from seed string using MD5 hash
  $md5 = [System.Security.Cryptography.MD5]::Create()
  $hash = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($SeedString))
  return [guid]::new($hash).ToString()
}

#endregion Helper Functions
