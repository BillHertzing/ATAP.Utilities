#Requires -Version 7.0
# Dual-purpose verification script: defines one function; runs it only under pwsh -File.
function Read-AceCommanderTierPostState {
  <#
  .SYNOPSIS
  Read-only post-state assertions for one ATAPUtilities tier (Sprint 0017 Task 17.68.dev).
  .DESCRIPTION
  Connects with Integrated Security and ApplicationIntent=ReadOnly and runs catalog/data SELECTs only.
  Asserts: Flyway history (count, success, max version, checksum of every row equal to the Flyway CRC32
  of the local migration file), the reset-migration objects (ACE.Person, ACE.User.PersonId), the Guest
  seed rows, and - once V00220 is applied - the AceCommander role, its grant row count and the
  <MachineName>\SvcAceCommander membership. Optionally compares the Ace/ATAPUtilities catalog signature
  with a reference instance (the accepted Experimental tier). Never writes, grants or reads secrets.
  .PARAMETER Instance
  SQL Server instance, for example UTAT022\Devwhertzing.
  .PARAMETER ExpectedHistoryRows
  Exact successful history row count expected (20 before V00220, 21 after).
  .PARAMETER ReferenceInstance
  Optional instance whose Ace/ATAPUtilities catalog signature must equal this one.
  .PARAMETER MigrationsPath
  Folder with V*.sql files (default: ../../Flyway/SQL relative to this script).
  .PARAMETER IncludeG6
  Whether the G6 VIEW DEFINITION grants are expected (default $true).
  .PARAMETER OutJson
  Optional path for the JSON receipt (write it under the caller's _generated folder).
  .OUTPUTS
  PSCustomObject with Instance, Passed and Checks (Name, Passed, Detail).
  .EXAMPLE
  pwsh -File Read-AceCommanderTierPostState.ps1 -Instance 'UTAT022\Devwhertzing' -ExpectedHistoryRows 20 -ReferenceInstance 'UTAT022\Expwhertzing'
  .NOTES
  Read-only. Run in a profiled pwsh child; never with -NoProfile.
  .LINK
  Database/Verify/AceCommander/AceCommanderRole.Contract.json
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Instance,
    [Parameter(Mandatory)][ValidateRange(1, 1000)][int]$ExpectedHistoryRows,
    [string]$ReferenceInstance,
    [string]$MigrationsPath,
    [bool]$IncludeG6 = $true,
    [string]$OutJson
  )
  begin {
    $fn = 'Read-AceCommanderTierPostState'; $mn = 'ATAPUtilities.Database.Verify'
    $canLog = [bool](Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)
    function writeLog([string]$Message) { if ($canLog) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $Message } }
    if (-not $MigrationsPath) { $MigrationsPath = Join-Path $PSScriptRoot '..\..\Flyway\SQL' }
    if (-not (Test-Path -LiteralPath $MigrationsPath -PathType Container)) { throw "Migrations folder not found: $MigrationsPath" }
    $guestUser = '5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e'; $guestPhilote = '3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b'

    function getFlywayChecksum([string]$Path) {
      $text = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false))
      if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
      $lines = [regex]::Split($text, "\r\n|\n|\r")
      if ($lines.Count -gt 0 -and $lines[-1] -eq '' -and ($text.EndsWith("`n") -or $text.EndsWith("`r"))) { $lines = $lines[0..($lines.Count - 2)] }
      $table = [uint32[]]::new(256)
      for ($i = 0; $i -lt 256; $i++) { $c = [uint32]$i; for ($k = 0; $k -lt 8; $k++) { if ($c -band 1) { $c = ([uint32]3988292384 -bxor ($c -shr 1)) } else { $c = [uint32]($c -shr 1) } }; $table[$i] = $c }
      $crc = [uint32]::MaxValue
      foreach ($line in $lines) { foreach ($b in [Text.Encoding]::UTF8.GetBytes($line)) { $crc = [uint32]($table[($crc -bxor $b) -band 0xFF] -bxor ($crc -shr 8)) } }
      [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]($crc -bxor [uint32]::MaxValue)), 0)
    }
    function invokeReadOnly([string]$Server, [string]$Sql) {
      $cs = "Server=$Server;Database=ATAPUtilities;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;ApplicationIntent=ReadOnly;Connect Timeout=15;Application Name=AceCommander-PostState-RO"
      $connection = [System.Data.SqlClient.SqlConnection]::new($cs)
      try {
        $connection.Open()
        $command = $connection.CreateCommand(); $command.CommandText = $Sql; $command.CommandTimeout = 60
        $table = [System.Data.DataTable]::new(); [void][System.Data.SqlClient.SqlDataAdapter]::new($command).Fill($table)
        , $table
      } finally { $connection.Dispose() }
    }
    # System-named constraints (for example FK__Membershi__Organ__4AA30C57) get a different generated
    # name in every database, so they are keyed by parent table, kind and definition instead of name.
    $signatureSql = @'
SELECT o.[type] COLLATE DATABASE_DEFAULT AS Kind, SCHEMA_NAME(o.[schema_id]) COLLATE DATABASE_DEFAULT AS SchemaName,
       CASE WHEN COALESCE(kc.[is_system_named], fk.[is_system_named], dc.[is_system_named], cc.[is_system_named], 0) = 1
            THEN N'~' + OBJECT_NAME(o.[parent_object_id]) COLLATE DATABASE_DEFAULT
               + N'~' + ISNULL((SELECT STRING_AGG(CONVERT(nvarchar(max), CONCAT(COL_NAME(f.[parent_object_id], f.[parent_column_id]), N'>', OBJECT_SCHEMA_NAME(f.[referenced_object_id]), N'.', OBJECT_NAME(f.[referenced_object_id]), N'.', COL_NAME(f.[referenced_object_id], f.[referenced_column_id]))), N',') WITHIN GROUP (ORDER BY f.[constraint_column_id])
                                FROM sys.foreign_key_columns AS f WHERE f.[constraint_object_id] = o.[object_id]) COLLATE DATABASE_DEFAULT, N'')
               + N'~' + ISNULL((SELECT STRING_AGG(CONVERT(nvarchar(max), COL_NAME(ic.[object_id], ic.[column_id])), N',') WITHIN GROUP (ORDER BY ic.[key_ordinal])
                                FROM sys.index_columns AS ic WHERE ic.[object_id] = kc.[parent_object_id] AND ic.[index_id] = kc.[unique_index_id]) COLLATE DATABASE_DEFAULT, N'')
               + N'~' + ISNULL(COL_NAME(dc.[parent_object_id], dc.[parent_column_id]) COLLATE DATABASE_DEFAULT, N'')
            ELSE o.[name] COLLATE DATABASE_DEFAULT END AS Name,
       CONVERT(varchar(64), HASHBYTES('SHA2_256', ISNULL(REPLACE(OBJECT_DEFINITION(o.[object_id]), NCHAR(13), N''), N'')), 2) AS DefinitionHash,
       (SELECT STRING_AGG(CONVERT(nvarchar(max), CONCAT(c.[name], N':', TYPE_NAME(c.[user_type_id]), N':', c.[max_length], N':', c.[is_nullable])), N',') WITHIN GROUP (ORDER BY c.[column_id])
        FROM sys.columns AS c WHERE c.[object_id] = o.[object_id]) AS Columns
FROM sys.objects AS o
LEFT JOIN sys.key_constraints AS kc ON kc.[object_id] = o.[object_id]
LEFT JOIN sys.foreign_keys AS fk ON fk.[object_id] = o.[object_id]
LEFT JOIN sys.default_constraints AS dc ON dc.[object_id] = o.[object_id]
LEFT JOIN sys.check_constraints AS cc ON cc.[object_id] = o.[object_id]
WHERE SCHEMA_NAME(o.[schema_id]) IN (N'Ace', N'ATAPUtilities') AND o.[is_ms_shipped] = 0 AND o.[type] IN ('U', 'V', 'P', 'FN', 'IF', 'TF', 'TR', 'C', 'F', 'PK', 'UQ', 'D')
ORDER BY 1, 2, 3, 4;
'@
    function getSignature([string]$Server) {
      $rows = invokeReadOnly $Server $signatureSql
      $text = ($rows.Rows | ForEach-Object { "$($_.Kind)|$($_.SchemaName)|$($_.Name)|$($_.DefinitionHash)|$($_.Columns)" }) -join "`n"
      [pscustomobject]@{ Objects = $rows.Rows.Count; Sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))) }
    }
  }
  process {
    $checks = [System.Collections.Generic.List[object]]::new()
    function add([string]$Name, [bool]$Passed, [string]$Detail) { $checks.Add([pscustomobject][ordered]@{ Name = $Name; Passed = $Passed; Detail = $Detail }) }
    writeLog "Reading post-state of $Instance (read-only)."

    $history = invokeReadOnly $Instance 'SELECT installed_rank AS [Rank], version AS Version, script AS Script, checksum AS Checksum, success AS Success FROM dbo.flyway_schema_history ORDER BY installed_rank;'
    $rows = @($history.Rows)
    add 'HistoryRowCount' ($rows.Count -eq $ExpectedHistoryRows) "rows=$($rows.Count) expected=$ExpectedHistoryRows"
    add 'HistoryAllSuccessful' (@($rows | Where-Object { -not [bool]$_.Success }).Count -eq 0) "failed=$(@($rows | Where-Object { -not [bool]$_.Success }).Count)"
    $maxVersion = if ($rows.Count) { [string]$rows[-1].Version } else { '' }
    add 'HistoryMaxVersion' ($maxVersion -ceq $(if ($ExpectedHistoryRows -ge 21) { '00220' } else { '00210' })) "max=$maxVersion"
    $mismatch = foreach ($row in $rows) {
      if ([string]::IsNullOrEmpty([string]$row.Script) -or $row.Script -is [DBNull]) { continue }
      $file = Join-Path $MigrationsPath ([string]$row.Script)
      if (-not (Test-Path -LiteralPath $file)) { "$($row.Version):no-local-file"; continue }
      $expected = getFlywayChecksum $file
      if ([int]$row.Checksum -ne $expected) { "$($row.Version):live=$($row.Checksum),file=$expected" }
    }
    add 'HistoryChecksumsMatchMigrationFiles' (@($mismatch).Count -eq 0) ((@($mismatch) -join '; ') + $(if (@($mismatch).Count -eq 0) { "all $($rows.Count) match" } else { '' }))

    $objects = (invokeReadOnly $Instance @"
SELECT CASE WHEN OBJECT_ID(N'ACE.Person', N'U') IS NULL THEN 0 ELSE 1 END AS PersonTable,
       CASE WHEN COL_LENGTH(N'ACE.User', N'PersonId') IS NULL THEN 0 ELSE 1 END AS UserPersonId,
       (SELECT COUNT(*) FROM [Ace].[User] WHERE [UserId] = '$guestUser') AS GuestUser,
       (SELECT COUNT(*) FROM [ATAPUtilities].[Philote] WHERE [PhiloteId] = '$guestPhilote') AS GuestPhilote,
       (SELECT COUNT(*) FROM [Ace].[User]) AS UserRows;
"@).Rows[0]
    add 'ResetMigrationObjects' ([int]$objects.PersonTable -eq 1 -and [int]$objects.UserPersonId -eq 1) "Person=$($objects.PersonTable) User.PersonId=$($objects.UserPersonId)"
    add 'GuestSeedPresent' ([int]$objects.GuestUser -eq 1 -and [int]$objects.GuestPhilote -eq 1) "GuestUser=$($objects.GuestUser) GuestPhilote=$($objects.GuestPhilote) UserRows=$($objects.UserRows)"

    if ($rows | Where-Object { [string]$_.Version -ceq '00220' }) {
      $role = (invokeReadOnly $Instance @"
DECLARE @Account sysname = CONVERT(sysname, SERVERPROPERTY('MachineName')) + N'\SvcAceCommander';
SELECT CASE WHEN DATABASE_PRINCIPAL_ID(N'AceCommander') IS NULL THEN 0 ELSE 1 END AS RolePresent,
       (SELECT COUNT(*) FROM sys.database_permissions WHERE [grantee_principal_id] = DATABASE_PRINCIPAL_ID(N'AceCommander') AND [state] = 'G') AS GrantRows,
       (SELECT COUNT(*) FROM sys.database_role_members AS rm JOIN sys.database_principals AS m ON m.[principal_id] = rm.[member_principal_id]
         WHERE rm.[role_principal_id] = DATABASE_PRINCIPAL_ID(N'AceCommander') AND m.[sid] = SUSER_SID(@Account)) AS MemberPresent;
"@).Rows[0]
      $expectedGrants = if ($IncludeG6) { 67 } else { 65 }
      add 'AceCommanderRole' ([int]$role.RolePresent -eq 1 -and [int]$role.GrantRows -eq $expectedGrants -and [int]$role.MemberPresent -eq 1) "role=$($role.RolePresent) grants=$($role.GrantRows)/$expectedGrants member=$($role.MemberPresent)"
    }

    $signature = getSignature $Instance
    $result = [ordered]@{ Utc = [DateTime]::UtcNow.ToString('o'); RunAs = [Security.Principal.WindowsIdentity]::GetCurrent().Name; Instance = $Instance; CatalogSignature = $signature }
    if ($ReferenceInstance) {
      $reference = getSignature $ReferenceInstance
      $result.ReferenceInstance = $ReferenceInstance; $result.ReferenceSignature = $reference
      add 'CatalogSignatureEqualsReference' ($signature.Sha256 -ceq $reference.Sha256) "this=$($signature.Sha256.Substring(0, 12))/$($signature.Objects) reference=$($reference.Sha256.Substring(0, 12))/$($reference.Objects)"
    }
    $result.Checks = @($checks)
    $result.Passed = (@($checks | Where-Object { -not $_.Passed }).Count -eq 0)
    if ($OutJson) { $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutJson -Encoding utf8 }
    [pscustomobject]$result
  }
  end { }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&' -and $PSCommandPath -like '*.ps1') {
  Read-AceCommanderTierPostState @args
}
