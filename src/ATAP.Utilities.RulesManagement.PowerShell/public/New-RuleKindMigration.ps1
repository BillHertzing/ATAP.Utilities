<#
.SYNOPSIS
    Generates a Flyway migration SQL file that inserts a new primitive language kind.
.DESCRIPTION
    Builds a SQL Server Flyway migration for the current ATAPUtilities RRSBS
    schema. The generated migration seeds:

      1. ATAPUtilities.PrimitiveLanguageKind
      2. ATAPUtilities.Philote
      3. ATAPUtilities.RulePrimitive
      4. ATAPUtilities.RulePrimitiveInput

    The function accepts the KindDefinition shape used by
    Add-RuleKindToCompendium, with these additional optional properties:

      PrimitiveLanguageKindId - explicit TINYINT id for the language kind
      MigrationVersion        - Flyway version string, e.g. 00.01.000070

    Each primitive may include PhiloteId, PrimitiveName, BNFSymbol, Name,
    Description, and Inputs. Each input may include InputName, InputType or
    TypeName, Description, DefaultValue, and IsRequired.
.PARAMETER KindDefinition
    PSCustomObject describing the kind and its primitives.
.PARAMETER MigrationsPath
    Path to the folder that holds the existing Flyway SQL migration files.
.OUTPUTS
    PSCustomObject with FilePath, Sql, and VersionNumber.
#>
function New-RuleKindMigration {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [ValidateNotNull()]
    [PSCustomObject] $KindDefinition,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string] $MigrationsPath
  )

  begin {
    $fn = 'New-RuleKindMigration'
    $mn = 'ATAP.Utilities.RulesManagement.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    try {
      if (-not (Get-Command -Name 'Get-PVal' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Get-PVal load skipped: $($_.Exception.Message)"
    }

    if (Get-Command -Name 'Get-PVal' -CommandType Function -ErrorAction SilentlyContinue) {
      $KindDefinition = Get-PVal -ParameterName 'KindDefinition' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.KindDefinition' -DefaultValue $KindDefinition
      $MigrationsPath = Get-PVal -ParameterName 'MigrationsPath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.MigrationsPath' -DefaultValue $MigrationsPath
    }

    foreach ($required in @('KindName', 'LanguageName', 'Description')) {
      if ([string]::IsNullOrWhiteSpace($KindDefinition.$required)) {
        throw "KindDefinition.$required is required and was not supplied"
      }
    }
    if (-not (Test-Path -LiteralPath $MigrationsPath -PathType Container)) {
      throw "MigrationsPath not found or is not a directory: $MigrationsPath"
    }
  }

  process {
    function ConvertTo-SqlString {
      param([AllowNull()][object]$Value)

      if ($null -eq $Value) {
        return 'NULL'
      }

      $stringValue = [string]$Value
      if ([string]::IsNullOrEmpty($stringValue)) {
        return 'NULL'
      }

      return "N'$($stringValue.Replace("'", "''"))'"
    }

    function ConvertTo-BitLiteral {
      param([object]$Value, [bool]$Default = $true)

      if ($null -eq $Value) {
        return $(if ($Default) { '1' } else { '0' })
      }

      return $(if ([System.Convert]::ToBoolean($Value)) { '1' } else { '0' })
    }

    try {
      $migrationVersion = $KindDefinition.MigrationVersion
      if ([string]::IsNullOrWhiteSpace($migrationVersion)) {
        $existingSemanticVersions = @(
          Get-ChildItem -LiteralPath $MigrationsPath -Filter 'V*.sql' -File |
            ForEach-Object {
              if ($_.Name -match '^V(?<Major>\d+)\.(?<Minor>\d+)\.(?<Patch>\d+)__') {
                [PSCustomObject]@{
                  Major = [int]$Matches['Major']
                  Minor = [int]$Matches['Minor']
                  Patch = [int]$Matches['Patch']
                }
              }
            }
        )

        $lastSemanticVersion = $existingSemanticVersions |
          Sort-Object Major, Minor, Patch |
          Select-Object -Last 1

        $migrationVersion = if ($lastSemanticVersion) {
          '{0:00}.{1:00}.{2:000000}' -f $lastSemanticVersion.Major, $lastSemanticVersion.Minor, ($lastSemanticVersion.Patch + 1)
        } else {
          '00.01.000001'
        }
      }

      $safeKindName = ([string]$KindDefinition.KindName) -replace '[^A-Za-z0-9]+', '_'
      $fileName = "V${migrationVersion}__Add_${safeKindName}_Rule_Kind.sql"
      $outputPath = Join-Path $MigrationsPath $fileName

      $kindId = if ($KindDefinition.PrimitiveLanguageKindId) { [int]$KindDefinition.PrimitiveLanguageKindId } else { 0 }
      $kindName = [string]$KindDefinition.KindName
      $description = [string]$KindDefinition.Description

      $sb = [System.Text.StringBuilder]::new()
      [void]$sb.AppendLine("-- =====================================================================")
      [void]$sb.AppendLine("-- $fileName")
      [void]$sb.AppendLine("-- Generated by New-RuleKindMigration")
      [void]$sb.AppendLine("-- =====================================================================")
      [void]$sb.AppendLine('SET XACT_ABORT ON;')
      [void]$sb.AppendLine('SET NOCOUNT ON;')
      [void]$sb.AppendLine('')
      [void]$sb.AppendLine('BEGIN TRANSACTION;')
      [void]$sb.AppendLine('')
      [void]$sb.AppendLine('BEGIN TRY')

      if ($kindId -gt 0) {
        [void]$sb.AppendLine('    IF NOT EXISTS (')
        [void]$sb.AppendLine('        SELECT 1 FROM ATAPUtilities.PrimitiveLanguageKind')
        [void]$sb.AppendLine("        WHERE PrimitiveLanguageKindId = $kindId OR [Name] = $(ConvertTo-SqlString $kindName)")
        [void]$sb.AppendLine('    )')
        [void]$sb.AppendLine('    BEGIN')
        [void]$sb.AppendLine('        INSERT INTO ATAPUtilities.PrimitiveLanguageKind')
        [void]$sb.AppendLine('            (PrimitiveLanguageKindId, [Name], [Description])')
        [void]$sb.AppendLine('        VALUES')
        [void]$sb.AppendLine("            ($kindId, $(ConvertTo-SqlString $kindName), $(ConvertTo-SqlString $description));")
        [void]$sb.AppendLine('    END;')
      } else {
        [void]$sb.AppendLine('    DECLARE @NextPrimitiveLanguageKindId TINYINT = (')
        [void]$sb.AppendLine('        SELECT ISNULL(MAX(PrimitiveLanguageKindId), 0) + 1')
        [void]$sb.AppendLine('        FROM ATAPUtilities.PrimitiveLanguageKind')
        [void]$sb.AppendLine('    );')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('    IF NOT EXISTS (')
        [void]$sb.AppendLine('        SELECT 1 FROM ATAPUtilities.PrimitiveLanguageKind')
        [void]$sb.AppendLine("        WHERE [Name] = $(ConvertTo-SqlString $kindName)")
        [void]$sb.AppendLine('    )')
        [void]$sb.AppendLine('    BEGIN')
        [void]$sb.AppendLine('        INSERT INTO ATAPUtilities.PrimitiveLanguageKind')
        [void]$sb.AppendLine('            (PrimitiveLanguageKindId, [Name], [Description])')
        [void]$sb.AppendLine('        VALUES')
        [void]$sb.AppendLine("            (@NextPrimitiveLanguageKindId, $(ConvertTo-SqlString $kindName), $(ConvertTo-SqlString $description));")
        [void]$sb.AppendLine('    END;')
      }

      [void]$sb.AppendLine('')
      [void]$sb.AppendLine('    DECLARE @PrimitiveLanguageKindId TINYINT =')
      [void]$sb.AppendLine("        (SELECT PrimitiveLanguageKindId FROM ATAPUtilities.PrimitiveLanguageKind WHERE [Name] = $(ConvertTo-SqlString $kindName));")
      [void]$sb.AppendLine('')
      [void]$sb.AppendLine('    DECLARE @Primitives TABLE (')
      [void]$sb.AppendLine('        PhiloteId UNIQUEIDENTIFIER NOT NULL,')
      [void]$sb.AppendLine('        [Name] NVARCHAR(200) NOT NULL,')
      [void]$sb.AppendLine('        [Description] NVARCHAR(MAX) NULL')
      [void]$sb.AppendLine('    );')
      [void]$sb.AppendLine('')
      [void]$sb.AppendLine('    INSERT INTO @Primitives (PhiloteId, [Name], [Description])')
      [void]$sb.AppendLine('    VALUES')

      $primitiveRows = @()
      foreach ($primitive in @($KindDefinition.Primitives)) {
        $philoteId = if ($primitive.PhiloteId) { [guid]$primitive.PhiloteId } else { [guid]::NewGuid() }
        $primitiveName = if ($primitive.PrimitiveName) { [string]$primitive.PrimitiveName } elseif ($primitive.Name) { [string]$primitive.Name } else { [string]$primitive.BNFSymbol }
        $primitiveDescription = [string]$primitive.Description
        $primitiveRows += "        ('$philoteId', $(ConvertTo-SqlString $primitiveName), $(ConvertTo-SqlString $primitiveDescription))"
      }
      [void]$sb.AppendLine(($primitiveRows -join ",`r`n") + ';')
      [void]$sb.AppendLine('')
      [void]$sb.AppendLine('    INSERT INTO ATAPUtilities.Philote (PhiloteId)')
      [void]$sb.AppendLine('    SELECT p.PhiloteId')
      [void]$sb.AppendLine('    FROM @Primitives AS p')
      [void]$sb.AppendLine('    WHERE NOT EXISTS (SELECT 1 FROM ATAPUtilities.Philote AS existing WHERE existing.PhiloteId = p.PhiloteId);')
      [void]$sb.AppendLine('')
      [void]$sb.AppendLine('    INSERT INTO ATAPUtilities.RulePrimitive')
      [void]$sb.AppendLine('        (PhiloteId, PrimitiveLanguageKindId, [Name], [Description])')
      [void]$sb.AppendLine('    SELECT p.PhiloteId, @PrimitiveLanguageKindId, p.[Name], p.[Description]')
      [void]$sb.AppendLine('    FROM @Primitives AS p')
      [void]$sb.AppendLine('    WHERE NOT EXISTS (SELECT 1 FROM ATAPUtilities.RulePrimitive AS existing WHERE existing.PhiloteId = p.PhiloteId);')

      $inputRows = @()
      foreach ($primitive in @($KindDefinition.Primitives)) {
        $primitiveName = if ($primitive.PrimitiveName) { [string]$primitive.PrimitiveName } elseif ($primitive.Name) { [string]$primitive.Name } else { [string]$primitive.BNFSymbol }
        foreach ($input in @($primitive.Inputs)) {
          $typeName = if ($input.TypeName) { [string]$input.TypeName } else { [string]$input.InputType }
          $inputRows += "        ($(ConvertTo-SqlString $primitiveName), $(ConvertTo-SqlString $input.InputName), $(ConvertTo-SqlString $typeName), $(ConvertTo-SqlString $input.Description), $(ConvertTo-SqlString $input.DefaultValue), $(ConvertTo-BitLiteral $input.IsRequired))"
        }
      }

      if ($inputRows.Count -gt 0) {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('    DECLARE @Inputs TABLE (')
        [void]$sb.AppendLine('        PrimitiveName NVARCHAR(200) NOT NULL,')
        [void]$sb.AppendLine('        InputName NVARCHAR(200) NOT NULL,')
        [void]$sb.AppendLine('        TypeName NVARCHAR(200) NULL,')
        [void]$sb.AppendLine('        [Description] NVARCHAR(MAX) NULL,')
        [void]$sb.AppendLine('        DefaultValue NVARCHAR(MAX) NULL,')
        [void]$sb.AppendLine('        IsRequired BIT NOT NULL')
        [void]$sb.AppendLine('    );')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('    INSERT INTO @Inputs (PrimitiveName, InputName, TypeName, [Description], DefaultValue, IsRequired)')
        [void]$sb.AppendLine('    VALUES')
        [void]$sb.AppendLine(($inputRows -join ",`r`n") + ';')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('    INSERT INTO ATAPUtilities.RulePrimitiveInput')
        [void]$sb.AppendLine('        (PhiloteId, InputName, TypeName, [Description], DefaultValue, IsRequired)')
        [void]$sb.AppendLine('    SELECT rp.PhiloteId, i.InputName, i.TypeName, i.[Description], i.DefaultValue, i.IsRequired')
        [void]$sb.AppendLine('    FROM @Inputs AS i')
        [void]$sb.AppendLine('    INNER JOIN ATAPUtilities.RulePrimitive AS rp')
        [void]$sb.AppendLine('        ON rp.PrimitiveLanguageKindId = @PrimitiveLanguageKindId')
        [void]$sb.AppendLine('       AND rp.[Name] = i.PrimitiveName')
        [void]$sb.AppendLine('    WHERE NOT EXISTS (')
        [void]$sb.AppendLine('        SELECT 1')
        [void]$sb.AppendLine('        FROM ATAPUtilities.RulePrimitiveInput AS existing')
        [void]$sb.AppendLine('        WHERE existing.PhiloteId = rp.PhiloteId')
        [void]$sb.AppendLine('          AND existing.InputName = i.InputName')
        [void]$sb.AppendLine('    );')
      }

      [void]$sb.AppendLine('')
      [void]$sb.AppendLine('    COMMIT TRANSACTION;')
      [void]$sb.AppendLine('END TRY')
      [void]$sb.AppendLine('BEGIN CATCH')
      [void]$sb.AppendLine('    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;')
      [void]$sb.AppendLine('    THROW;')
      [void]$sb.AppendLine('END CATCH;')

      $sql = $sb.ToString()

      if ($PSCmdlet.ShouldProcess($outputPath, 'Write Flyway migration file')) {
        [System.IO.File]::WriteAllText($outputPath, $sql, [System.Text.Encoding]::UTF8)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Migration written: $outputPath"

        return [PSCustomObject]@{
          FilePath      = $outputPath
          Sql           = $sql
          VersionNumber = $migrationVersion
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "WhatIf: would write $outputPath ($($sql.Length) chars)"
      return [PSCustomObject]@{
        FilePath      = $null
        Sql           = $sql
        VersionNumber = $migrationVersion
      }
    } catch {
      $errorMessage = "New-RuleKindMigration failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
