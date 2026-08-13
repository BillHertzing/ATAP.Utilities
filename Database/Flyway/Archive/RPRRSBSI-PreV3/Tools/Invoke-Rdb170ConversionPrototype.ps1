function Invoke-Rdb170ConversionPrototype {
  <#
  .SYNOPSIS
  Produces deterministic, source-only RDB-170 conversion evidence.

  .DESCRIPTION
  Maps each active Flyway CSV seed input to its current source-known target
  shape. The function reads only the source corpus and writes evidence to the
  supplied output directory. It does not emit target seeds, allocate target
  identities, or execute SQL.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $RepositoryRoot,

    [Parameter(Mandatory)]
    [string] $OutputDirectory
  )

  begin {
    $fn = 'Invoke-Rdb170ConversionPrototype'
    $mn = 'Database.Tools'
    $dataDirectory = Join-Path $RepositoryRoot 'Database/Flyway/Data'
    $v1Path = Join-Path $RepositoryRoot 'Database/Flyway/SQL/V00.02.000110__Seed_ATAPorg_Instantiation_V1.sql'
    $v2Path = Join-Path $RepositoryRoot 'Database/Flyway/SQL/V00.02.000140__Seed_ATAPorg_Instantiation_V2_Markdown.sql'

    if (-not (Test-Path -LiteralPath $dataDirectory -PathType Container)) {
      throw "Active Flyway data directory does not exist: $dataDirectory"
    }

    foreach ($requiredPath in @($v1Path, $v2Path)) {
      if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required frozen source artifact does not exist: $requiredPath"
      }
    }

    $targetShapes = @{
      'InstantiationBindings' = 'RuleInstantiationBinding'
      'Instantiations' = 'RuleInstantiation'
      'Philote_Instantiations' = 'Philote'
      'Philote_Primitives' = 'Philote'
      'Philote_Rules' = 'Rule'
      'RulePrimitives' = 'RulePrimitive'
      'Rules' = 'Rule'
      'Snippet_Philote_RuleSets' = 'RuleSet'
      'Snippet_RuleSets' = 'RuleSet'
      'User_UserInformation' = 'UserInformation'
      'User_Users' = 'User'
      'User_UserSettings' = 'UserSettings'
    }
  }

  process {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $records = foreach ($file in Get-ChildItem -LiteralPath $dataDirectory -Filter '*.csv' -File | Sort-Object Name) {
      $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
      $sourceClass = switch -Regex ($baseName) {
        '_InstantiationBindings$' { 'InstantiationBindings'; break }
        '_Instantiations$' { 'Instantiations'; break }
        '_Philote_Instantiations$' { 'Philote_Instantiations'; break }
        '_Philote_Primitives$' { 'Philote_Primitives'; break }
        '_Philote_Rules$' { 'Philote_Rules'; break }
        '_RulePrimitives$' { 'RulePrimitives'; break }
        '_Rules$' { 'Rules'; break }
        default { $baseName }
      }

      if (-not $targetShapes.ContainsKey($sourceClass)) {
        throw "No approved source-only target-shape mapping exists for '$($file.Name)' (class '$sourceClass')."
      }

      $unreferenced = $sourceClass -in @('Snippet_Philote_RuleSets', 'Snippet_RuleSets')
      [pscustomobject][ordered]@{
        sourceFile = $file.Name
        sourceClass = $sourceClass
        targetShape = $targetShapes[$sourceClass]
        sourceRows = (Get-Content -LiteralPath $file.FullName | Measure-Object -Line).Lines - 1
        sourceSha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        ambiguity = if ($unreferenced) {
          'No active loader reference; no target seed may be inferred.'
        } else {
          'Target-shape mapping only; semantic identities remain RDB-160 pending.'
        }
      }
    }

    if ($records.Count -ne 47) {
      throw "Expected 47 frozen CSV inputs; found $($records.Count)."
    }

    $rowTotal = ($records | Measure-Object -Property sourceRows -Sum).Sum
    if ($rowTotal -ne 517) {
      throw "Expected 517 frozen source rows; found $rowTotal."
    }

    $json = ConvertTo-Json -InputObject @($records) -Compress -Depth 4
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $jsonPath = Join-Path $OutputDirectory 'CanonicalSeedShapeMap.json'
    [IO.File]::WriteAllText($jsonPath, $json, $utf8NoBom)

    $csvPath = Join-Path $OutputDirectory 'CsvConversionMapping.csv'
    $records | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8

    $markdownCorpusPath = Join-Path $RepositoryRoot 'SolutionDocumentation/Rules Compendium.Markdown.md'
    if (-not (Test-Path -LiteralPath $markdownCorpusPath -PathType Leaf)) {
      throw "Markdown corpus authority does not exist: $markdownCorpusPath"
    }

    $jsonHash = (Get-FileHash -LiteralPath $jsonPath -Algorithm SHA256).Hash
    $v1Hash = (Get-FileHash -LiteralPath $v1Path -Algorithm SHA256).Hash
    $v2Hash = (Get-FileHash -LiteralPath $v2Path -Algorithm SHA256).Hash
    $markdownCorpusHash = (Get-FileHash -LiteralPath $markdownCorpusPath -Algorithm SHA256).Hash
    $inlineCode = [char]96
    $evidence = @"
# RDB-170 — Deterministic Conversion Reconciliation Evidence

| Check | Result |
| --- | --- |
| Canonical conversion map SHA-256 | $inlineCode$jsonHash$inlineCode |
| CSV inputs mapped | $($records.Count) |
| Source rows represented | $rowTotal |
| Explicitly unresolved unreferenced RuleSet inputs | $(@($records | Where-Object { $_.ambiguity -like 'No active loader reference*' }).Count) |
| V1 source artifact SHA-256 | $inlineCode$v1Hash$inlineCode |
| V2 Markdown source artifact SHA-256 | $inlineCode$v2Hash$inlineCode |
| Markdown corpus authority SHA-256 | $inlineCode$markdownCorpusHash$inlineCode |
| Collision/ambiguity report | 159 reused GUIDs remain source-semantic transform inputs; no target collision freedom is asserted. |

The prototype serializes frozen source-to-target seed shapes deterministically. It does not claim byte-identical target reconstruction because the approved target schema and target registry are not yet implemented; that proof remains a Wave 3/4 prerequisite.
"@
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'ReconciliationEvidence.md'), $evidence, $utf8NoBom)

    [pscustomobject]@{
      MappingPath = $csvPath
      CanonicalMapPath = $jsonPath
      CanonicalMapSha256 = $jsonHash
      InputCount = $records.Count
      SourceRowCount = $rowTotal
    }
  }

  end {
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  Invoke-Rdb170ConversionPrototype @args
}
