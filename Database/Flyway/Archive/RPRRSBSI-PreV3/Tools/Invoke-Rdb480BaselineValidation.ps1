[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string[]] $Path,

  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
  [string] $ScriptDomAssemblyPath,

  [switch] $RequireTransactionEnvelope
)

function Invoke-Rdb480BaselineValidation {
  <#
  .SYNOPSIS
  Parses and statically validates RRSBS V2 SQL fragments or the integrated baseline.

  .DESCRIPTION
  Uses ScriptDom's SQL Server 2022 parser and enforces the source-only RDB-480
  guardrails that can be proven without connecting to a database. Literal
  dynamic SQL is parsed separately; variable or parenthesized dynamic SQL is
  rejected so every executable SQL statement is covered by ScriptDom.

  .PARAMETER Path
  One or more SQL files to validate.

  .PARAMETER ScriptDomAssemblyPath
  An installed Microsoft.SqlServer.TransactSql.ScriptDom assembly. The validator
  never downloads or installs a parser dependency.

  .PARAMETER RequireTransactionEnvelope
  Requires the validated file to contain the complete RDB-480 transaction
  markers. Omit for disjoint fragments whose transaction is coordinator-owned.

  .OUTPUTS
  PSCustomObject validation results, one per input file.

  .EXAMPLE
  Invoke-Rdb480BaselineValidation -Path '.\Database\Flyway\SQL\V00010__Create_RRSBS_Baseline.sql' `
    -ScriptDomAssemblyPath 'C:\Program Files\JetBrains\JetBrains Rider 2026.1.3\plugins\sqlproj-plugin\Rider.Sqlproj.Worker\Microsoft.SqlServer.TransactSql.ScriptDom.dll'

  .NOTES
  This tool performs no database, package, feed, credential, reset, or live-tier
  operation. RDB-480 double-run proof remains a separate disposable-environment gate.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $Path,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $ScriptDomAssemblyPath,

    [switch] $RequireTransactionEnvelope
  )

  begin {
    $fn = 'Invoke-Rdb480BaselineValidation'
    $mn = 'ATAP.Utilities.Database.Tools'

    try {
      if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
        Add-Type -LiteralPath $ScriptDomAssemblyPath -ErrorAction Stop
      }
    } catch {
      throw "$fn could not load ScriptDom from '$ScriptDomAssemblyPath': $($_.Exception.Message)"
    }

    $resolvedPaths = [System.Collections.Generic.List[string]]::new()
    $registryContractPath = Join-Path $PSScriptRoot '..\Documentation\RRSBS-RDB-320-Object-GUID-Registries.md'
    if (-not (Test-Path -LiteralPath $registryContractPath -PathType Leaf)) {
      throw "$fn could not find the RDB-320 registry contract: $registryContractPath"
    }
    $registryContractText = Get-Content -LiteralPath $registryContractPath -Raw -ErrorAction Stop
    $registeredTriggerSection = [regex]::Match(
      $registryContractText,
      '(?s)<!-- RDB320-WAVE5-TRIGGERS:BEGIN -->(?<body>.*?)<!-- RDB320-WAVE5-TRIGGERS:END -->'
    )
    if (-not $registeredTriggerSection.Success) {
      throw "$fn found no Wave 5 trigger registry markers in $registryContractPath"
    }
    $registeredTriggerNames = @(
      [regex]::Matches($registeredTriggerSection.Groups['body'].Value, '(?m)^- `(?<name>TR_[A-Za-z0-9_]+)`\s*$') |
        ForEach-Object { $_.Groups['name'].Value }
    )
    $registeredPhysicalSection = [regex]::Match(
      $registryContractText,
      '(?s)<!-- RDB320-WAVE5-PHYSICAL:BEGIN -->(?<body>.*?)<!-- RDB320-WAVE5-PHYSICAL:END -->'
    )
    if (-not $registeredPhysicalSection.Success) {
      throw "$fn found no Wave 5 physical-object registry markers in $registryContractPath"
    }
    $registeredPhysicalObjects = @(
      [regex]::Matches(
        $registeredPhysicalSection.Groups['body'].Value,
        '(?m)^- `(?<type>ROLE|TABLE|PROCEDURE)\|(?<name>[A-Za-z][A-Za-z0-9_]*)`\s*$'
      ) | ForEach-Object {
        [pscustomobject]@{
          ObjectType = $_.Groups['type'].Value
          ObjectName = $_.Groups['name'].Value
        }
      }
    )
  }

  process {
    foreach ($item in $Path) {
      $resolved = (Resolve-Path -LiteralPath $item -ErrorAction Stop).Path
      [void] $resolvedPaths.Add($resolved)
    }
  }

  end {
    foreach ($resolved in $resolvedPaths) {
      $text = Get-Content -LiteralPath $resolved -Raw -ErrorAction Stop
      $parseErrors = [System.Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
      $reader = [System.IO.StringReader]::new($text)

      try {
        $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
        $null = $parser.Parse($reader, [ref] $parseErrors)
      } finally {
        $reader.Dispose()
      }

      $createTableNames = @(
        [regex]::Matches(
          $text,
          '(?im)\bCREATE\s+TABLE\s+(?:\[(?<schema>[^\]]+)\]|(?<schema>[A-Za-z_][A-Za-z0-9_]*))\s*\.\s*(?:\[(?<table>[^\]]+)\]|(?<table>[A-Za-z_][A-Za-z0-9_]*))'
        ) | ForEach-Object { "$($_.Groups['schema'].Value).$($_.Groups['table'].Value)" }
      )
      $duplicateCreateTables = @(
        $createTableNames |
          Group-Object |
          Where-Object Count -gt 1 |
          Select-Object -ExpandProperty Name
      )
      $createdProcedureNames = @(
        [regex]::Matches(
          $text,
          '(?im)\bCREATE\s+OR\s+ALTER\s+PROCEDURE\s+(?:\[ATAPUtilities\]|ATAPUtilities)\s*\.\s*(?:\[(?<name>[A-Za-z][A-Za-z0-9_]*)\]|(?<name>[A-Za-z][A-Za-z0-9_]*))'
        ) | ForEach-Object { $_.Groups['name'].Value }
      )

      $staticIssues = [System.Collections.Generic.List[string]]::new()
      $staticText = [regex]::Replace($text, '(?s)/\*.*?\*/', '')
      $staticText = [regex]::Replace($staticText, '(?m)--.*$', '')
      if ($staticText -match '(?im)^\s*USE\s+') {
        [void] $staticIssues.Add('Database-context changes with USE are forbidden.')
      }
      if ($staticText -match '(?im)^\s*:r\s+') {
        [void] $staticIssues.Add('SQLCMD :r includes are forbidden in the immutable baseline.')
      }
      $dynamicSqlMatches = @(
        [regex]::Matches(
          $text,
          "(?is)\b(?:EXEC(?:UTE)?\s+)?sys\.sp_executesql\s+N'(?<sql>(?:''|[^'])*)'\s*;"
        )
      )
      $dynamicSqlParseErrors = [System.Collections.Generic.List[object]]::new()
      $dynamicSqlOrdinal = 0
      foreach ($dynamicSqlMatch in $dynamicSqlMatches) {
        $dynamicSqlOrdinal++
        $dynamicSql = $dynamicSqlMatch.Groups['sql'].Value.Replace("''", "'")
        $dynamicErrors = [System.Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
        $dynamicReader = [System.IO.StringReader]::new($dynamicSql)
        try {
          $dynamicParser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
          $null = $dynamicParser.Parse($dynamicReader, [ref] $dynamicErrors)
        } finally {
          $dynamicReader.Dispose()
        }
        foreach ($dynamicError in $dynamicErrors) {
          $dynamicSqlParseErrors.Add([PSCustomObject]@{
              Ordinal = $dynamicSqlOrdinal
              Line = $dynamicError.Line
              Column = $dynamicError.Column
              Number = $dynamicError.Number
              Message = $dynamicError.Message
            })
        }
      }
      if ($staticText -match '(?i)\bsp_executesql\s+@|\bEXEC(?:UTE)?\s*\(') {
        [void] $staticIssues.Add('Variable or parenthesized dynamic SQL is forbidden; RDB-480 must expand it to separately parsed N-string literals.')
      }
      if ($staticText -match '(?i)\bV00\.\d') {
        [void] $staticIssues.Add('Legacy V00.* lineage references are forbidden in the RRSBS V2 baseline.')
      }
      if ($duplicateCreateTables.Count -gt 0) {
        [void] $staticIssues.Add("Duplicate CREATE TABLE targets: $($duplicateCreateTables -join ', ')")
      }

      $createdTriggerNames = @(
        [regex]::Matches(
          $staticText,
          '(?im)\bCREATE\s+OR\s+ALTER\s+TRIGGER\s+(?:\[ATAPUtilities\]|ATAPUtilities)\s*\.\s*(?:\[(?<name>TR_[A-Za-z0-9_]+)\]|(?<name>TR_[A-Za-z0-9_]+))'
        ) | ForEach-Object { $_.Groups['name'].Value }
      )
      $duplicateTriggerNames = @(
        $createdTriggerNames |
          Group-Object -CaseSensitive:$false |
          Where-Object Count -gt 1 |
          Select-Object -ExpandProperty Name
      )
      if ($duplicateTriggerNames.Count -gt 0) {
        [void] $staticIssues.Add("Duplicate CREATE OR ALTER TRIGGER targets: $($duplicateTriggerNames -join ', ')")
      }
      $createdTriggerSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($createdTriggerName in $createdTriggerNames) {
        [void] $createdTriggerSet.Add($createdTriggerName)
      }
      $missingRegisteredTriggers = @(
        $registeredTriggerNames | Where-Object { -not $createdTriggerSet.Contains($_) }
      )
      if ($RequireTransactionEnvelope -and $missingRegisteredTriggers.Count -gt 0) {
        [void] $staticIssues.Add("Missing RDB-320 registered triggers: $($missingRegisteredTriggers -join ', ')")
      }
      $createdTableSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($createdTableName in $createTableNames) {
        [void] $createdTableSet.Add(($createdTableName -split '\.', 2)[1])
      }
      $createdProcedureSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($createdProcedureName in $createdProcedureNames) {
        [void] $createdProcedureSet.Add($createdProcedureName)
      }
      $missingRegisteredPhysicalObjects = @(
        foreach ($registeredPhysicalObject in $registeredPhysicalObjects) {
          $present = switch ($registeredPhysicalObject.ObjectType) {
            'ROLE' { $text -match "(?im)\bCREATE\s+ROLE\s+\[$([regex]::Escape($registeredPhysicalObject.ObjectName))\]" }
            'TABLE' { $createdTableSet.Contains($registeredPhysicalObject.ObjectName) }
            'PROCEDURE' { $createdProcedureSet.Contains($registeredPhysicalObject.ObjectName) }
          }
          if (-not $present) {
            "$($registeredPhysicalObject.ObjectType)|$($registeredPhysicalObject.ObjectName)"
          }
        }
      )
      if ($RequireTransactionEnvelope -and $missingRegisteredPhysicalObjects.Count -gt 0) {
        [void] $staticIssues.Add("Missing RDB-320 physical amendment objects: $($missingRegisteredPhysicalObjects -join ', ')")
      }

      $transactionMarkers = [ordered]@{
        XactAbort = [bool]($text -match '(?im)\bSET\s+XACT_ABORT\s+ON\b')
        Try = [bool]($text -match '(?im)\bBEGIN\s+TRY\b')
        BeginTransaction = [bool]($text -match '(?im)\bBEGIN\s+TRAN(?:SACTION)?\b')
        Commit = [bool]($text -match '(?im)\bCOMMIT(?:\s+TRAN(?:SACTION)?)?\b')
        Catch = [bool]($text -match '(?im)\bBEGIN\s+CATCH\b')
        XactState = [bool]($text -match '(?im)\bXACT_STATE\s*\(')
        Throw = [bool]($text -match '(?im)\bTHROW\s*;')
      }
      $missingTransactionMarkers = @(
        $transactionMarkers.GetEnumerator() |
          Where-Object { -not $_.Value } |
          Select-Object -ExpandProperty Key
      )
      if ($RequireTransactionEnvelope -and $missingTransactionMarkers.Count -gt 0) {
        [void] $staticIssues.Add("Missing transaction markers: $($missingTransactionMarkers -join ', ')")
      }

      $hash = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
      [PSCustomObject]@{
        Path = $resolved
        Sha256 = $hash
        ParseSucceeded = $parseErrors.Count -eq 0
        ParseErrors = @($parseErrors | ForEach-Object {
          [PSCustomObject]@{
            Line = $_.Line
            Column = $_.Column
            Number = $_.Number
            Message = $_.Message
          }
        })
        DynamicSqlLiteralCount = $dynamicSqlMatches.Count
        DynamicSqlParseErrors = @($dynamicSqlParseErrors)
        CreatedTriggerCount = $createdTriggerNames.Count
        MissingRegisteredTriggers = $missingRegisteredTriggers
        CreatedProcedureCount = $createdProcedureNames.Count
        MissingRegisteredPhysicalObjects = $missingRegisteredPhysicalObjects
        CreateTableCount = $createTableNames.Count
        CreateTables = $createTableNames
        StaticIssues = @($staticIssues)
        TransactionMarkers = [PSCustomObject]$transactionMarkers
        Passed = $parseErrors.Count -eq 0 -and $dynamicSqlParseErrors.Count -eq 0 -and $staticIssues.Count -eq 0
      }
    }
  }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  Invoke-Rdb480BaselineValidation @PSBoundParameters
}
