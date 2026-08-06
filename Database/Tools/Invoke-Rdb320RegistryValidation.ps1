<#
.SYNOPSIS
Validates and materializes the RDB-320 source-static registry evidence.

.DESCRIPTION
Reads the approved logical-model PlantUML sources, the RDB-270 EntityType
allow-list, the RDB-160 source GUID register, the RDB-170 source hash map, and
the HITL RDB-320 worksheet. It writes generated CSV mirrors and Evidence.md.
This standalone evidence script performs no SQL, network, package, or live-tier
operation.
#>

function Invoke-Rdb320RegistryValidation {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter()]
    [string] $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,

    [Parameter()]
    [string] $PlanningRoot = 'C:\Dropbox\whertzing\GitHub\_Planning-wt-33-Sprint-0014-work-items'
  )

  begin {
    $fn = 'Invoke-Rdb320RegistryValidation'
    $mn = 'RDB-320-Evidence'
    $namespaceGuid = [guid] '509d3589-e658-445d-8bde-67ad2e9d64cf'
    $evidenceRoot = Join-Path $RepositoryRoot '_generated\RRSBS-V2\RDB-320'
    $documentationRoot = Join-Path $RepositoryRoot 'Database\Documentation'
    $worksheetPath = Join-Path $PlanningRoot 'InformationForTheFuture\RRSBS-Rationalization\RDB-320-Source-Identity-Resolution-Worksheet.md'
    $sourceRegisterPath = Join-Path $RepositoryRoot '_generated\RRSBS-V2\RDB-160\SeededIdentityDispositionRegister.csv'
    $conversionMapPath = Join-Path $RepositoryRoot '_generated\RRSBS-V2\RDB-170\CsvConversionMapping.csv'
    $contractPath = Join-Path $documentationRoot 'RRSBS-RDB-320-Object-GUID-Registries.md'

    function ConvertTo-NetworkGuidBytes {
      param([Parameter(Mandatory)][guid] $Guid)
      $bytes = $Guid.ToByteArray()
      [array]::Reverse($bytes, 0, 4)
      [array]::Reverse($bytes, 4, 2)
      [array]::Reverse($bytes, 6, 2)
      return $bytes
    }

    function New-UuidV5 {
      param(
        [Parameter(Mandatory)][guid] $Namespace,
        [Parameter(Mandatory)][string] $Name
      )
      $namespaceBytes = ConvertTo-NetworkGuidBytes -Guid $Namespace
      $nameBytes = [Text.Encoding]::UTF8.GetBytes($Name)
      $inputBytes = [byte[]]::new($namespaceBytes.Length + $nameBytes.Length)
      [array]::Copy($namespaceBytes, 0, $inputBytes, 0, $namespaceBytes.Length)
      [array]::Copy($nameBytes, 0, $inputBytes, $namespaceBytes.Length, $nameBytes.Length)
      $hash = [Security.Cryptography.SHA1]::HashData($inputBytes)
      $uuidBytes = [byte[]] $hash[0..15]
      $uuidBytes[6] = ($uuidBytes[6] -band 0x0f) -bor 0x50
      $uuidBytes[8] = ($uuidBytes[8] -band 0x3f) -bor 0x80
      [array]::Reverse($uuidBytes, 0, 4)
      [array]::Reverse($uuidBytes, 4, 2)
      [array]::Reverse($uuidBytes, 6, 2)
      return [guid]::new($uuidBytes)
    }

    function ConvertTo-CanonicalSegment {
      param([Parameter(Mandatory)][string] $Value)
      $normalized = $Value.Trim().Normalize([Text.NormalizationForm]::FormC).ToLowerInvariant()
      return "$($normalized.Length):$normalized"
    }

    function ConvertTo-TableName {
      param([Parameter(Mandatory)][string] $EntityTypeCode)
      return (($EntityTypeCode -split '-') | ForEach-Object {
          $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1)
        }) -join ''
    }

    function Get-Sha256 {
      param([Parameter(Mandatory)][string] $LiteralPath)
      return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash
    }
  }

  process {
    try {
      foreach ($requiredPath in @($worksheetPath, $sourceRegisterPath, $conversionMapPath, $contractPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
          throw "Required RDB-320 input does not exist: $requiredPath"
        }
      }

      $contractText = Get-Content -LiteralPath $contractPath -Raw -ErrorAction Stop
      $triggerSection = [regex]::Match(
        $contractText,
        '(?s)<!-- RDB320-WAVE5-TRIGGERS:BEGIN -->(?<body>.*?)<!-- RDB320-WAVE5-TRIGGERS:END -->'
      )
      if (-not $triggerSection.Success) {
        throw 'RDB-320 Wave 5 trigger registry markers are absent.'
      }
      $wave5TriggerNames = @(
        [regex]::Matches($triggerSection.Groups['body'].Value, '(?m)^- `(?<name>TR_[A-Za-z0-9_]+)`\s*$') |
          ForEach-Object { $_.Groups['name'].Value }
      )
      $triggerNameSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($triggerName in $wave5TriggerNames) {
        if ($triggerName.Length -gt 128) {
          throw "Wave 5 trigger name exceeds SQL Server's identifier limit: $triggerName"
        }
        if (-not $triggerNameSet.Add($triggerName)) {
          throw "Duplicate Wave 5 trigger name under ordinal case-insensitive comparison: $triggerName"
        }
      }
      if ($wave5TriggerNames.Count -ne 109) {
        throw "Wave 5 trigger registry count drift: expected 109, actual $($wave5TriggerNames.Count)."
      }

      $physicalSection = [regex]::Match(
        $contractText,
        '(?s)<!-- RDB320-WAVE5-PHYSICAL:BEGIN -->(?<body>.*?)<!-- RDB320-WAVE5-PHYSICAL:END -->'
      )
      if (-not $physicalSection.Success) {
        throw 'RDB-320 Wave 5 physical-object registry markers are absent.'
      }
      $wave5PhysicalObjects = @(
        [regex]::Matches(
          $physicalSection.Groups['body'].Value,
          '(?m)^- `(?<type>ROLE|TABLE|PROCEDURE)\|(?<name>[A-Za-z][A-Za-z0-9_]*)`\s*$'
        ) | ForEach-Object {
          [pscustomobject]@{
            ObjectType = $_.Groups['type'].Value
            ObjectName = $_.Groups['name'].Value
          }
        }
      )
      $physicalObjectSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($physicalObject in $wave5PhysicalObjects) {
        $key = "$($physicalObject.ObjectType)|$($physicalObject.ObjectName)"
        if (-not $physicalObjectSet.Add($key)) {
          throw "Duplicate Wave 5 physical object under ordinal case-insensitive comparison: $key"
        }
      }
      $physicalRoleCount = @($wave5PhysicalObjects | Where-Object ObjectType -eq 'ROLE').Count
      $physicalTableCount = @($wave5PhysicalObjects | Where-Object ObjectType -eq 'TABLE').Count
      $physicalProcedureCount = @($wave5PhysicalObjects | Where-Object ObjectType -eq 'PROCEDURE').Count
      if (($wave5PhysicalObjects.Count -ne 31) -or
          ($physicalRoleCount -ne 1) -or
          ($physicalTableCount -ne 10) -or
          ($physicalProcedureCount -ne 20)) {
        throw 'Wave 5 physical registry count drift: expected 1 role, 10 tables, and 20 procedures.'
      }

      $rfcVector = New-UuidV5 -Namespace ([guid] '6ba7b810-9dad-11d1-80b4-00c04fd430c8') -Name 'www.widgets.com'
      if ($rfcVector.Guid -ne '21f7f8de-8051-5b89-8680-0195ef798b6a') {
        throw "UUIDv5 implementation failed the RFC vector: $($rfcVector.Guid)"
      }

      $sliceFiles = [ordered]@{
        'RDB-200' = 'RRSBS-RDB-200-Identity-Authority-Domain-Tag-Attribution-Logical-Model.puml'
        'RDB-210' = 'RRSBS-RDB-210-RuleKind-Primitive-ValueType-Logical-Model.puml'
        'RDB-220' = 'RRSBS-RDB-220-Rule-Composition-Logical-Model.puml'
        'RDB-230' = 'RRSBS-RDB-230-RuleSet-BuildSet-Logical-Model.puml'
        'RDB-240' = 'RRSBS-RDB-240-Instantiation-InputBlock-Logical-Model.puml'
        'RDB-250' = 'RRSBS-RDB-250-Plan-Approval-Run-Artifact-Event-Usage-Logical-Model.puml'
        'RDB-260' = 'RRSBS-RDB-260-Context-SourceArtifact-AgentText-ContentSummary-Logical-Model.puml'
      }
      $expectedCounts = [ordered]@{
        'RDB-200' = 18
        'RDB-210' = 18
        'RDB-220' = 9
        'RDB-230' = 8
        'RDB-240' = 12
        'RDB-250' = 11
        'RDB-260' = 13
      }

      $objectRegistry = [Collections.Generic.List[object]]::new()
      $philoteRegistry = [Collections.Generic.List[object]]::new()
      foreach ($slice in $sliceFiles.Keys) {
        $pumlPath = Join-Path $documentationRoot $sliceFiles[$slice]
        if (-not (Test-Path -LiteralPath $pumlPath -PathType Leaf)) {
          throw "Logical-model source does not exist: $pumlPath"
        }
        $currentEntity = $null
        $currentStereotype = $null
        foreach ($line in Get-Content -LiteralPath $pumlPath) {
          if ($line -match '^\s+entity\s+(?<name>[A-Za-z][A-Za-z0-9]*)\s+<<(?<stereotype>[^>]+)>>') {
            $currentEntity = $Matches.name
            $currentStereotype = $Matches.stereotype
            if ($currentStereotype -notmatch '\bexternal\b') {
              $objectRegistry.Add([pscustomobject]@{
                  Owner = $slice
                  SchemaName = 'ATAPUtilities'
                  ObjectType = 'TABLE'
                  ObjectName = $currentEntity
                  QualifiedName = "[ATAPUtilities].[$currentEntity]"
                })
            }
            continue
          }
          if ($currentEntity -and $currentStereotype -notmatch '\bexternal\b' -and $line -match '\*\s+(?<column>[A-Za-z][A-Za-z0-9]*PhiloteId)\s+:') {
            $philoteRegistry.Add([pscustomobject]@{
                Owner = $slice
                TableName = $currentEntity
                PhiloteColumn = $Matches.column
                EntityTypeCode = ''
              })
          }
          if ($line -match '^\s*}') {
            $currentEntity = $null
            $currentStereotype = $null
          }
        }
        $actualCount = @($objectRegistry | Where-Object Owner -eq $slice).Count
        if ($actualCount -ne $expectedCounts[$slice]) {
          throw "$slice object count drift: expected $($expectedCounts[$slice]), actual $actualCount"
        }
      }
      if ($objectRegistry.Count -ne 89 -or ($objectRegistry.ObjectName | Sort-Object -Unique).Count -ne 89) {
        throw "Object registry is not 89 unique names; actual $($objectRegistry.Count)."
      }
      if (@($objectRegistry | Where-Object { $_.ObjectName.Length -gt 128 }).Count) {
        throw 'An object registry name exceeds SQL Server''s 128-character identifier limit.'
      }
      if ($philoteRegistry.Count -ne 51) {
        throw "Philote registry count drift: expected 51, actual $($philoteRegistry.Count)."
      }

      $rdb270Path = Join-Path $documentationRoot 'RRSBS-RDB-270-Integrated-Logical-Model.md'
      $entityTypeCodes = [Collections.Generic.List[string]]::new()
      foreach ($line in Get-Content -LiteralPath $rdb270Path) {
        if ($line -match '^\| RDB-2\d\d \| (?<codes>.+) \|$') {
          foreach ($match in [regex]::Matches($Matches.codes, '`(?<code>[a-z][a-z0-9-]+)`')) {
            $entityTypeCodes.Add($match.Groups['code'].Value)
          }
        }
      }
      if ($entityTypeCodes.Count -ne 43 -or ($entityTypeCodes | Sort-Object -Unique).Count -ne 43) {
        throw "EntityType allow-list drift: expected 43 unique codes, actual $($entityTypeCodes.Count)."
      }
      foreach ($code in $entityTypeCodes) {
        $table = ConvertTo-TableName -EntityTypeCode $code
        $philote = $philoteRegistry | Where-Object TableName -eq $table
        if (@($philote).Count -ne 1) {
          throw "EntityType '$code' does not resolve to exactly one Philote table '$table'."
        }
        $philote.EntityTypeCode = $code
      }

      $worksheetRows = [Collections.Generic.List[object]]::new()
      foreach ($line in Get-Content -LiteralPath $worksheetPath) {
        if ($line -notmatch '^\| [0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12} ') {
          continue
        }
        $parts = $line -split ' \| '
        if ($parts.Count -ne 5) {
          throw "Malformed worksheet row: $line"
        }
        $sourceGuid = [guid] ($parts[0].Trim().TrimStart('|').Trim())
        $desired = $parts[3].Trim()
        if ($desired -match '^RetainAsTargetPhilote; Primitive; (?<kind>[A-Za-z]+)\\\|(?<code>.+)$') {
          $kind = $Matches.kind
          if ($kind -eq 'Powershell') { $kind = 'PowerShell' }
          $worksheetRows.Add([pscustomobject]@{
              SourceGuid = $sourceGuid.Guid.ToLowerInvariant()
              Disposition = 'RetainAsTargetPhilote'
              RuleKindCode = $kind
              PrimitiveCode = $Matches.code.Trim()
            })
        } elseif ($desired -in @('Not to be migrated', 'Do not migrate')) {
          $worksheetRows.Add([pscustomobject]@{
              SourceGuid = $sourceGuid.Guid.ToLowerInvariant()
              Disposition = 'DoNotMigrate'
              RuleKindCode = ''
              PrimitiveCode = ''
            })
        } else {
          throw "Unknown or blank worksheet disposition for ${sourceGuid}: '$desired'"
        }
      }
      if ($worksheetRows.Count -ne 175) {
        throw "Worksheet count drift: expected 175, actual $($worksheetRows.Count)."
      }
      $retainedRows = @($worksheetRows | Where-Object Disposition -eq 'RetainAsTargetPhilote')
      $disposedRows = @($worksheetRows | Where-Object Disposition -eq 'DoNotMigrate')
      if ($retainedRows.Count -ne 72 -or $disposedRows.Count -ne 103) {
        throw "Worksheet disposition drift: retained $($retainedRows.Count), disposed $($disposedRows.Count)."
      }
      $retainedKeys = @($retainedRows | ForEach-Object { "$($_.RuleKindCode)|$($_.PrimitiveCode)" })
      if (($retainedKeys | Sort-Object -Unique).Count -ne 72) {
        throw 'Retained Primitive natural keys are not unique.'
      }
      if (($retainedRows.SourceGuid | Sort-Object -Unique).Count -ne 72) {
        throw 'Retained Primitive Philotes are not unique.'
      }

      $sourceRows = @(Import-Csv -LiteralPath $sourceRegisterPath)
      if ($sourceRows.Count -ne 334 -or ($sourceRows.Guid | ForEach-Object ToLowerInvariant | Sort-Object -Unique).Count -ne 334) {
        throw "Source GUID register drift: expected 334 unique rows, actual $($sourceRows.Count)."
      }
      $sourceGuidSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($row in $sourceRows) { [void] $sourceGuidSet.Add(([guid] $row.Guid).Guid) }

      $targetManifest = [Collections.Generic.List[object]]::new()
      $ruleKinds = @($retainedRows.RuleKindCode | Sort-Object -Unique)
      if ($ruleKinds.Count -ne 7) {
        throw "Retained RuleKind count drift: expected 7, actual $($ruleKinds.Count)."
      }
      foreach ($kind in $ruleKinds) {
        $kindSegment = ConvertTo-CanonicalSegment -Value $kind
        $kindName = "rrsbs-v2/rule-kind/$kindSegment"
        $kindVersionName = "rrsbs-v2/rule-kind-version/$kindSegment/1"
        $targetManifest.Add([pscustomobject]@{
            EntityTypeCode = 'rule-kind'
            NaturalKey = $kind
            Revision = ''
            PhiloteId = (New-UuidV5 -Namespace $namespaceGuid -Name $kindName).Guid.ToLowerInvariant()
            Allocation = 'UUIDv5'
          })
        $targetManifest.Add([pscustomobject]@{
            EntityTypeCode = 'rule-kind-version'
            NaturalKey = $kind
            Revision = '1'
            PhiloteId = (New-UuidV5 -Namespace $namespaceGuid -Name $kindVersionName).Guid.ToLowerInvariant()
            Allocation = 'UUIDv5'
          })
      }
      foreach ($row in $retainedRows | Sort-Object RuleKindCode, PrimitiveCode) {
        $kindSegment = ConvertTo-CanonicalSegment -Value $row.RuleKindCode
        $codeSegment = ConvertTo-CanonicalSegment -Value $row.PrimitiveCode
        $targetManifest.Add([pscustomobject]@{
            EntityTypeCode = 'primitive'
            NaturalKey = "$($row.RuleKindCode)|$($row.PrimitiveCode)"
            Revision = ''
            PhiloteId = $row.SourceGuid
            Allocation = 'RetainedSource'
          })
        $versionName = "rrsbs-v2/primitive-version/$kindSegment/$codeSegment/1"
        $targetManifest.Add([pscustomobject]@{
            EntityTypeCode = 'primitive-version'
            NaturalKey = "$($row.RuleKindCode)|$($row.PrimitiveCode)"
            Revision = '1'
            PhiloteId = (New-UuidV5 -Namespace $namespaceGuid -Name $versionName).Guid.ToLowerInvariant()
            Allocation = 'UUIDv5'
          })
      }
      if ($targetManifest.Count -ne 158 -or ($targetManifest.PhiloteId | Sort-Object -Unique).Count -ne 158) {
        throw "Target manifest collision: expected 158 unique Philotes, actual $($targetManifest.Count)."
      }
      $allocatedRows = @($targetManifest | Where-Object Allocation -eq 'UUIDv5')
      if ($allocatedRows.Count -ne 86) {
        throw "UUIDv5 allocation count drift: expected 86, actual $($allocatedRows.Count)."
      }
      foreach ($row in $allocatedRows) {
        if (([guid] $row.PhiloteId).ToString()[14] -ne '5') {
          throw "Allocated Philote is not UUID version 5: $($row.PhiloteId)"
        }
        if ($sourceGuidSet.Contains($row.PhiloteId)) {
          throw "Allocated Philote collides with a source GUID: $($row.PhiloteId)"
        }
      }

      $conversionRows = @(Import-Csv -LiteralPath $conversionMapPath)
      if ($conversionRows.Count -ne 47 -or ($conversionRows | Measure-Object -Property sourceRows -Sum).Sum -ne 517) {
        throw 'RDB-170 conversion map drifted from 47 inputs / 517 rows.'
      }
      foreach ($row in $conversionRows) {
        $sourcePath = Join-Path $RepositoryRoot "Database\Flyway\Data\$($row.sourceFile)"
        if ((Get-Sha256 -LiteralPath $sourcePath) -ne $row.sourceSha256) {
          throw "Frozen RDB-170 source hash mismatch: $sourcePath"
        }
      }

      if ($PSCmdlet.ShouldProcess($evidenceRoot, 'Write RDB-320 generated registry evidence')) {
        New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
        $objectRegistry | Export-Csv -LiteralPath (Join-Path $evidenceRoot 'ObjectNameRegistry.csv') -NoTypeInformation
        $philoteRegistry | Export-Csv -LiteralPath (Join-Path $evidenceRoot 'EntityPhiloteRegistry.csv') -NoTypeInformation
        $targetManifest | Export-Csv -LiteralPath (Join-Path $evidenceRoot 'TargetPhiloteManifest.csv') -NoTypeInformation
        $wave5TriggerNames |
          ForEach-Object { [pscustomobject]@{ TriggerName = $_ } } |
          Export-Csv -LiteralPath (Join-Path $evidenceRoot 'TriggerNameRegistry.csv') -NoTypeInformation
        $wave5PhysicalObjects |
          Export-Csv -LiteralPath (Join-Path $evidenceRoot 'Wave5PhysicalObjectRegistry.csv') -NoTypeInformation

        $contractHash = Get-Sha256 -LiteralPath $contractPath
        $worksheetHash = Get-Sha256 -LiteralPath $worksheetPath
        $objectHash = Get-Sha256 -LiteralPath (Join-Path $evidenceRoot 'ObjectNameRegistry.csv')
        $entityHash = Get-Sha256 -LiteralPath (Join-Path $evidenceRoot 'EntityPhiloteRegistry.csv')
        $targetHash = Get-Sha256 -LiteralPath (Join-Path $evidenceRoot 'TargetPhiloteManifest.csv')
        $triggerHash = Get-Sha256 -LiteralPath (Join-Path $evidenceRoot 'TriggerNameRegistry.csv')
        $physicalObjectHash = Get-Sha256 -LiteralPath (Join-Path $evidenceRoot 'Wave5PhysicalObjectRegistry.csv')
        $validatorHash = Get-Sha256 -LiteralPath $PSCommandPath
        $evidence = @"
# RDB-320 Registry Evidence

Status: source-static validation complete. No SQL, package, network, live-tier,
backup, reset, or destructive operation was performed.

## Verified counts

| Measure | Value |
| --- | ---: |
| Registered local table/catalog objects | $($objectRegistry.Count) |
| Wave 5 registered physical triggers | $($wave5TriggerNames.Count) |
| Wave 5 physical amendment objects | $($wave5PhysicalObjects.Count) |
| Philote-bearing tables | $($philoteRegistry.Count) |
| Closed EntityType codes | $($entityTypeCodes.Count) |
| Frozen source GUIDs | $($sourceRows.Count) |
| HITL worksheet decisions | $($worksheetRows.Count) |
| Retained Primitive Philotes | $($retainedRows.Count) |
| Explicit non-migrations | $($disposedRows.Count) |
| UUIDv5 allocations | $($allocatedRows.Count) |
| Unique target manifest Philotes | $($targetManifest.Count) |
| RDB-170 frozen CSV inputs | $($conversionRows.Count) |
| RDB-170 frozen CSV rows | $(($conversionRows | Measure-Object -Property sourceRows -Sum).Sum) |
| UUIDv5/source collisions | 0 |

## SHA-256 evidence

| Artifact | SHA-256 |
| --- | --- |
| RDB-320 contract | ``$contractHash`` |
| HITL worksheet | ``$worksheetHash`` |
| ObjectNameRegistry.csv | ``$objectHash`` |
| EntityPhiloteRegistry.csv | ``$entityHash`` |
| TargetPhiloteManifest.csv | ``$targetHash`` |
| TriggerNameRegistry.csv | ``$triggerHash`` |
| Wave5PhysicalObjectRegistry.csv | ``$physicalObjectHash`` |
| Registry validator | ``$validatorHash`` |

The UUIDv5 implementation passed the RFC 4122 DNS namespace vector for
``www.widgets.com``. All current RDB-170 source hashes matched. Live-tier
collision and byte-equivalence claims remain explicitly unmade because the
RDB-010B/C capture was released uncompleted by user direction.
"@
        Set-Content -LiteralPath (Join-Path $evidenceRoot 'Evidence.md') -Value $evidence -Encoding utf8NoBOM
      }

      return [pscustomobject]@{
        Objects = $objectRegistry.Count
        Wave5Triggers = $wave5TriggerNames.Count
        Wave5PhysicalObjects = $wave5PhysicalObjects.Count
        PhiloteTables = $philoteRegistry.Count
        EntityTypes = $entityTypeCodes.Count
        SourceGuids = $sourceRows.Count
        WorksheetRows = $worksheetRows.Count
        Retained = $retainedRows.Count
        Disposed = $disposedRows.Count
        Allocated = $allocatedRows.Count
        TargetPhilotes = $targetManifest.Count
        SourceFiles = $conversionRows.Count
        SourceRows = ($conversionRows | Measure-Object -Property sourceRows -Sum).Sum
      }
    } catch {
      if (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message
      }
      throw
    }
  }

  end {
  }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  Invoke-Rdb320RegistryValidation @args
}
