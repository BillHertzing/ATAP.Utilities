<#
.SYNOPSIS
    Loads agent and instruction source files into AgentText-shaped objects.
.DESCRIPTION
    Reads Markdown, TOML, and manifest files used by the SharedVSCode .ai pilot
    and produces normalized objects that can be inserted into the AgentText
    RRSBS tables or round-tripped by Export-AgentTextToFiles.

    The function intentionally works without a live database so sprint agents can
    validate file parsing and round-trip behavior in isolated worktrees. When
    -AsSql is supplied, it also emits idempotent SQL fragments for the pilot
    AgentText tables created by the AgentText Flyway migration.
#>
function Import-AgentTextFromFiles {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ManifestPath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $SourceRoot,

    [switch] $AsSql
  )

  begin {
    $fn = 'Import-AgentTextFromFiles'
    $mn = 'ATAP.Utilities.RulesManagement.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
      throw "ManifestPath not found: $ManifestPath"
    }

    function Get-AgentTextHash {
      param([Parameter(Mandatory = $true)][string] $Path)

      $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path)
      $sha = [System.Security.Cryptography.SHA256]::Create()
      try {
        $hash = ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
      }
      finally {
        $sha.Dispose()
      }

      [PSCustomObject]@{
        Sha256 = $hash
        Bytes  = $bytes.Length
      }
    }

    function ConvertTo-AgentTextSqlString {
      param([AllowNull()][object] $Value)

      if ($null -eq $Value) { return 'NULL' }
      $stringValue = [string]$Value
      if ([string]::IsNullOrEmpty($stringValue)) { return 'NULL' }
      return "N'$($stringValue.Replace("'", "''"))'"
    }

    function Get-AgentTextBodyFormat {
      param([Parameter(Mandatory = $true)][string] $Path)

      switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.toml' { 'toml'; break }
        '.json' { 'json'; break }
        default { 'markdown' }
      }
    }
  }

  process {
    try {
      $manifestFull = [System.IO.Path]::GetFullPath($ManifestPath)
      $manifest = Get-Content -LiteralPath $manifestFull -Raw | ConvertFrom-Json
      $repoRoot = if ($SourceRoot) {
        [System.IO.Path]::GetFullPath($SourceRoot)
      }
      else {
        $manifestDir = Split-Path -Path $manifestFull -Parent
        $aiRoot = Split-Path -Path $manifestDir -Parent
        Split-Path -Path $aiRoot -Parent
      }

      $rows = [System.Collections.Generic.List[object]]::new()
      foreach ($record in @($manifest.records)) {
        $sourcePath = if ([System.IO.Path]::IsPathRooted([string]$record.source.path)) {
          [string]$record.source.path
        }
        else {
          Join-Path -Path $repoRoot -ChildPath ([string]$record.source.path)
        }

        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
          throw "AgentText source not found for $($record.id): $sourcePath"
        }

        $body = [System.IO.File]::ReadAllText($sourcePath, [System.Text.Encoding]::UTF8)
        $hash = Get-AgentTextHash -Path $sourcePath
        if ($record.source.sha256 -and $hash.Sha256 -ne $record.source.sha256) {
          throw "Source hash mismatch for $($record.id): expected $($record.source.sha256), actual $($hash.Sha256)"
        }

        $targets = @($record.targets | ForEach-Object {
          [PSCustomObject]@{
            Tool            = [string]$_.tool
            Path            = [string]$_.path
            Materialization = [string]$_.materialization
            RenderedSha256  = if ($_.rendered) { [string]$_.rendered.sha256 } else { $null }
            RenderedBytes   = if ($_.rendered) { [int]$_.rendered.bytes } else { $null }
          }
        })

        $toolSurface = @()
        if ($body -match '(?ms)^tools:\s*(?<tools>\[[\s\S]*?\])') {
          $toolSurface = @(
            $Matches['tools'].Trim('[',']') -split ',' |
              ForEach-Object { $_.Trim().Trim('"').Trim("'") } |
              Where-Object { $_ }
          )
        }

        $roundTripPolicy = if (@($targets | Where-Object { $_.RenderedSha256 }).Count -eq $targets.Count -and $targets.Count -gt 0) {
          'byte-for-byte'
        }
        else {
          'semantic'
        }

        $row = [PSCustomObject]@{
          AgentTextId     = [guid]::NewGuid()
          SourceId        = [string]$record.id
          Kind            = [string]$record.kind
          DisplayName     = [string]$record.displayName
          SourcePath      = [string]$record.source.path
          BodyFormat      = Get-AgentTextBodyFormat -Path $sourcePath
          BodySha256      = $hash.Sha256
          BodyBytes       = $hash.Bytes
          BodyText        = $body
          ToolSurface     = $toolSurface
          AdapterTargets  = $targets
          RoundTripPolicy = $roundTripPolicy
        }

        if ($AsSql) {
          $agentTextId = [string]$row.AgentTextId
          $sql = [System.Text.StringBuilder]::new()
          [void]$sql.AppendLine("IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.AgentText WHERE SourceId = $(ConvertTo-AgentTextSqlString $row.SourceId))")
          [void]$sql.AppendLine('BEGIN')
          [void]$sql.AppendLine('    INSERT INTO ATAPUtilities.AgentText')
          [void]$sql.AppendLine('        (AgentTextId, SourceId, Kind, DisplayName, SourcePath, BodyFormat, BodySha256, BodyText)')
          [void]$sql.AppendLine('    VALUES')
          [void]$sql.AppendLine("        ('$agentTextId', $(ConvertTo-AgentTextSqlString $row.SourceId), $(ConvertTo-AgentTextSqlString $row.Kind), $(ConvertTo-AgentTextSqlString $row.DisplayName), $(ConvertTo-AgentTextSqlString $row.SourcePath), $(ConvertTo-AgentTextSqlString $row.BodyFormat), '$($row.BodySha256)', $(ConvertTo-AgentTextSqlString $row.BodyText));")
          [void]$sql.AppendLine('END;')
          foreach ($tool in @($row.ToolSurface)) {
            [void]$sql.AppendLine("IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.AgentToolSurface WHERE AgentTextId = '$agentTextId' AND ToolName = $(ConvertTo-AgentTextSqlString $tool))")
            [void]$sql.AppendLine("    INSERT INTO ATAPUtilities.AgentToolSurface (AgentTextId, ToolName) VALUES ('$agentTextId', $(ConvertTo-AgentTextSqlString $tool));")
          }
          foreach ($target in @($row.AdapterTargets)) {
            [void]$sql.AppendLine("IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.AgentAdapterTarget WHERE AgentTextId = '$agentTextId' AND TargetPath = $(ConvertTo-AgentTextSqlString $target.Path))")
            [void]$sql.AppendLine('    INSERT INTO ATAPUtilities.AgentAdapterTarget (AgentTextId, ToolName, TargetPath, Materialization, RenderedSha256, RenderedBytes)')
            [void]$sql.AppendLine("    VALUES ('$agentTextId', $(ConvertTo-AgentTextSqlString $target.Tool), $(ConvertTo-AgentTextSqlString $target.Path), $(ConvertTo-AgentTextSqlString $target.Materialization), $(ConvertTo-AgentTextSqlString $target.RenderedSha256), $(if ($target.RenderedBytes) { $target.RenderedBytes } else { 'NULL' }));")
          }
          [void]$sql.AppendLine("IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.AgentTextRoundTrip WHERE AgentTextId = '$agentTextId')")
          [void]$sql.AppendLine("    INSERT INTO ATAPUtilities.AgentTextRoundTrip (AgentTextId, RoundTripPolicy, NormalizationNotes) VALUES ('$agentTextId', $(ConvertTo-AgentTextSqlString $row.RoundTripPolicy), NULL);")
          $row | Add-Member -NotePropertyName Sql -NotePropertyValue $sql.ToString() -Force
        }

        $rows.Add($row)
      }

      return [PSCustomObject]@{
        ManifestPath = $manifestFull
        SourceRoot   = $repoRoot
        Count        = $rows.Count
        Records      = $rows
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
