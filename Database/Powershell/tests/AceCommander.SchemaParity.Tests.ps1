# AI assisted using Powershell.instructions.md as guidelines

$SqlInstance = if ($env:ATAPUTILITIES_SQLINSTANCE) { $env:ATAPUTILITIES_SQLINSTANCE } else { 'localhost' }
$DatabaseName = 'ATAPUtilities'

Describe 'AceCommander schema and user data parity checks' {
  BeforeAll {
    if (-not (Get-Module -ListAvailable -Name dbatools)) {
      throw 'dbatools module is required for this test. Install-Module dbatools -Scope CurrentUser'
    }

    Import-Module dbatools -ErrorAction Stop

    Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig | Out-Null
    Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig | Out-Null
  }

  It 'validates AceCommander has the same tables, indexes, and foreign keys as ATAPUtilities' {
    $missingTablesCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query @'
WITH source_tables AS (
  SELECT t.name AS TableName
  FROM sys.tables t
  INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
  WHERE s.name = N'ATAPUtilities'
),
target_tables AS (
  SELECT t.name AS TableName
  FROM sys.tables t
  INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
  WHERE s.name = N'AceCommander'
)
SELECT COUNT(*)
FROM (SELECT TableName FROM source_tables EXCEPT SELECT TableName FROM target_tables) a;
'@)

    $extraTablesCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query @'
WITH source_tables AS (
  SELECT t.name AS TableName
  FROM sys.tables t
  INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
  WHERE s.name = N'ATAPUtilities'
),
target_tables AS (
  SELECT t.name AS TableName
  FROM sys.tables t
  INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
  WHERE s.name = N'AceCommander'
)
SELECT COUNT(*)
FROM (SELECT TableName FROM target_tables EXCEPT SELECT TableName FROM source_tables) a;
'@)

    $missingIndexCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query @'
WITH source_indexes AS (
  SELECT
    t.name AS TableName,
    i.type AS IndexType,
    i.is_unique AS IsUnique,
    i.is_primary_key AS IsPrimaryKey,
    i.is_unique_constraint AS IsUniqueConstraint,
    COALESCE(i.filter_definition, N'') AS FilterDefinition,
    COALESCE(
      STUFF((
        SELECT N'|' + c.name + N':' + CASE WHEN ic2.is_descending_key = 1 THEN N'DESC' ELSE N'ASC' END
        FROM sys.index_columns ic2
        INNER JOIN sys.columns c ON c.object_id = ic2.object_id AND c.column_id = ic2.column_id
        WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id AND ic2.key_ordinal > 0
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE
      ).value('.', 'nvarchar(max)'), 1, 1, N''), N''
    ) AS KeyColumns,
    COALESCE(
      STUFF((
        SELECT N'|' + c.name
        FROM sys.index_columns ic3
        INNER JOIN sys.columns c ON c.object_id = ic3.object_id AND c.column_id = ic3.column_id
        WHERE ic3.object_id = i.object_id AND ic3.index_id = i.index_id AND ic3.is_included_column = 1
        ORDER BY ic3.index_column_id
        FOR XML PATH(''), TYPE
      ).value('.', 'nvarchar(max)'), 1, 1, N''), N''
    ) AS IncludedColumns
  FROM sys.tables t
  INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
  INNER JOIN sys.indexes i ON i.object_id = t.object_id
  WHERE s.name = N'ATAPUtilities' AND i.is_hypothetical = 0 AND i.name IS NOT NULL
),
target_indexes AS (
  SELECT
    t.name AS TableName,
    i.type AS IndexType,
    i.is_unique AS IsUnique,
    i.is_primary_key AS IsPrimaryKey,
    i.is_unique_constraint AS IsUniqueConstraint,
    COALESCE(i.filter_definition, N'') AS FilterDefinition,
    COALESCE(
      STUFF((
        SELECT N'|' + c.name + N':' + CASE WHEN ic2.is_descending_key = 1 THEN N'DESC' ELSE N'ASC' END
        FROM sys.index_columns ic2
        INNER JOIN sys.columns c ON c.object_id = ic2.object_id AND c.column_id = ic2.column_id
        WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id AND ic2.key_ordinal > 0
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE
      ).value('.', 'nvarchar(max)'), 1, 1, N''), N''
    ) AS KeyColumns,
    COALESCE(
      STUFF((
        SELECT N'|' + c.name
        FROM sys.index_columns ic3
        INNER JOIN sys.columns c ON c.object_id = ic3.object_id AND c.column_id = ic3.column_id
        WHERE ic3.object_id = i.object_id AND ic3.index_id = i.index_id AND ic3.is_included_column = 1
        ORDER BY ic3.index_column_id
        FOR XML PATH(''), TYPE
      ).value('.', 'nvarchar(max)'), 1, 1, N''), N''
    ) AS IncludedColumns
  FROM sys.tables t
  INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
  INNER JOIN sys.indexes i ON i.object_id = t.object_id
  WHERE s.name = N'AceCommander' AND i.is_hypothetical = 0 AND i.name IS NOT NULL
)
SELECT COUNT(*)
FROM (
  SELECT TableName, IndexType, IsUnique, IsPrimaryKey, IsUniqueConstraint, FilterDefinition, KeyColumns, IncludedColumns
  FROM source_indexes
  EXCEPT
  SELECT TableName, IndexType, IsUnique, IsPrimaryKey, IsUniqueConstraint, FilterDefinition, KeyColumns, IncludedColumns
  FROM target_indexes
) a;
'@)

    $extraIndexCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query @'
WITH source_indexes AS (
  SELECT
    t.name AS TableName,
    i.type AS IndexType,
    i.is_unique AS IsUnique,
    i.is_primary_key AS IsPrimaryKey,
    i.is_unique_constraint AS IsUniqueConstraint,
    COALESCE(i.filter_definition, N'') AS FilterDefinition,
    COALESCE(
      STUFF((
        SELECT N'|' + c.name + N':' + CASE WHEN ic2.is_descending_key = 1 THEN N'DESC' ELSE N'ASC' END
        FROM sys.index_columns ic2
        INNER JOIN sys.columns c ON c.object_id = ic2.object_id AND c.column_id = ic2.column_id
        WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id AND ic2.key_ordinal > 0
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE
      ).value('.', 'nvarchar(max)'), 1, 1, N''), N''
    ) AS KeyColumns,
    COALESCE(
      STUFF((
        SELECT N'|' + c.name
        FROM sys.index_columns ic3
        INNER JOIN sys.columns c ON c.object_id = ic3.object_id AND c.column_id = ic3.column_id
        WHERE ic3.object_id = i.object_id AND ic3.index_id = i.index_id AND ic3.is_included_column = 1
        ORDER BY ic3.index_column_id
        FOR XML PATH(''), TYPE
      ).value('.', 'nvarchar(max)'), 1, 1, N''), N''
    ) AS IncludedColumns
  FROM sys.tables t
  INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
  INNER JOIN sys.indexes i ON i.object_id = t.object_id
  WHERE s.name = N'ATAPUtilities' AND i.is_hypothetical = 0 AND i.name IS NOT NULL
),
target_indexes AS (
  SELECT
    t.name AS TableName,
    i.type AS IndexType,
    i.is_unique AS IsUnique,
    i.is_primary_key AS IsPrimaryKey,
    i.is_unique_constraint AS IsUniqueConstraint,
    COALESCE(i.filter_definition, N'') AS FilterDefinition,
    COALESCE(
      STUFF((
        SELECT N'|' + c.name + N':' + CASE WHEN ic2.is_descending_key = 1 THEN N'DESC' ELSE N'ASC' END
        FROM sys.index_columns ic2
        INNER JOIN sys.columns c ON c.object_id = ic2.object_id AND c.column_id = ic2.column_id
        WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id AND ic2.key_ordinal > 0
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE
      ).value('.', 'nvarchar(max)'), 1, 1, N''), N''
    ) AS KeyColumns,
    COALESCE(
      STUFF((
        SELECT N'|' + c.name
        FROM sys.index_columns ic3
        INNER JOIN sys.columns c ON c.object_id = ic3.object_id AND c.column_id = ic3.column_id
        WHERE ic3.object_id = i.object_id AND ic3.index_id = i.index_id AND ic3.is_included_column = 1
        ORDER BY ic3.index_column_id
        FOR XML PATH(''), TYPE
      ).value('.', 'nvarchar(max)'), 1, 1, N''), N''
    ) AS IncludedColumns
  FROM sys.tables t
  INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
  INNER JOIN sys.indexes i ON i.object_id = t.object_id
  WHERE s.name = N'AceCommander' AND i.is_hypothetical = 0 AND i.name IS NOT NULL
)
SELECT COUNT(*)
FROM (
  SELECT TableName, IndexType, IsUnique, IsPrimaryKey, IsUniqueConstraint, FilterDefinition, KeyColumns, IncludedColumns
  FROM target_indexes
  EXCEPT
  SELECT TableName, IndexType, IsUnique, IsPrimaryKey, IsUniqueConstraint, FilterDefinition, KeyColumns, IncludedColumns
  FROM source_indexes
) a;
'@)

    $missingFkCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query @'
WITH source_fks AS (
  SELECT
    pt.name AS ParentTable,
    COALESCE(STUFF((
      SELECT N'|' + pc.name
      FROM sys.foreign_key_columns fkc2
      INNER JOIN sys.columns pc ON pc.object_id = fkc2.parent_object_id AND pc.column_id = fkc2.parent_column_id
      WHERE fkc2.constraint_object_id = fk.object_id
      ORDER BY fkc2.constraint_column_id
      FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N''), N'') AS ParentColumns,
    rt.name AS ReferencedTable,
    COALESCE(STUFF((
      SELECT N'|' + rc.name
      FROM sys.foreign_key_columns fkc3
      INNER JOIN sys.columns rc ON rc.object_id = fkc3.referenced_object_id AND rc.column_id = fkc3.referenced_column_id
      WHERE fkc3.constraint_object_id = fk.object_id
      ORDER BY fkc3.constraint_column_id
      FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N''), N'') AS ReferencedColumns,
    fk.delete_referential_action AS DeleteAction,
    fk.update_referential_action AS UpdateAction
  FROM sys.foreign_keys fk
  INNER JOIN sys.tables pt ON pt.object_id = fk.parent_object_id
  INNER JOIN sys.schemas ps ON ps.schema_id = pt.schema_id
  INNER JOIN sys.tables rt ON rt.object_id = fk.referenced_object_id
  INNER JOIN sys.schemas rs ON rs.schema_id = rt.schema_id
  WHERE ps.name = N'ATAPUtilities' AND rs.name = N'ATAPUtilities'
),
target_fks AS (
  SELECT
    pt.name AS ParentTable,
    COALESCE(STUFF((
      SELECT N'|' + pc.name
      FROM sys.foreign_key_columns fkc2
      INNER JOIN sys.columns pc ON pc.object_id = fkc2.parent_object_id AND pc.column_id = fkc2.parent_column_id
      WHERE fkc2.constraint_object_id = fk.object_id
      ORDER BY fkc2.constraint_column_id
      FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N''), N'') AS ParentColumns,
    rt.name AS ReferencedTable,
    COALESCE(STUFF((
      SELECT N'|' + rc.name
      FROM sys.foreign_key_columns fkc3
      INNER JOIN sys.columns rc ON rc.object_id = fkc3.referenced_object_id AND rc.column_id = fkc3.referenced_column_id
      WHERE fkc3.constraint_object_id = fk.object_id
      ORDER BY fkc3.constraint_column_id
      FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N''), N'') AS ReferencedColumns,
    fk.delete_referential_action AS DeleteAction,
    fk.update_referential_action AS UpdateAction
  FROM sys.foreign_keys fk
  INNER JOIN sys.tables pt ON pt.object_id = fk.parent_object_id
  INNER JOIN sys.schemas ps ON ps.schema_id = pt.schema_id
  INNER JOIN sys.tables rt ON rt.object_id = fk.referenced_object_id
  INNER JOIN sys.schemas rs ON rs.schema_id = rt.schema_id
  WHERE ps.name = N'AceCommander' AND rs.name = N'AceCommander'
)
SELECT COUNT(*)
FROM (
  SELECT ParentTable, ParentColumns, ReferencedTable, ReferencedColumns, DeleteAction, UpdateAction
  FROM source_fks
  EXCEPT
  SELECT ParentTable, ParentColumns, ReferencedTable, ReferencedColumns, DeleteAction, UpdateAction
  FROM target_fks
) a;
'@)

    $extraFkCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query @'
WITH source_fks AS (
  SELECT
    pt.name AS ParentTable,
    COALESCE(STUFF((
      SELECT N'|' + pc.name
      FROM sys.foreign_key_columns fkc2
      INNER JOIN sys.columns pc ON pc.object_id = fkc2.parent_object_id AND pc.column_id = fkc2.parent_column_id
      WHERE fkc2.constraint_object_id = fk.object_id
      ORDER BY fkc2.constraint_column_id
      FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N''), N'') AS ParentColumns,
    rt.name AS ReferencedTable,
    COALESCE(STUFF((
      SELECT N'|' + rc.name
      FROM sys.foreign_key_columns fkc3
      INNER JOIN sys.columns rc ON rc.object_id = fkc3.referenced_object_id AND rc.column_id = fkc3.referenced_column_id
      WHERE fkc3.constraint_object_id = fk.object_id
      ORDER BY fkc3.constraint_column_id
      FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N''), N'') AS ReferencedColumns,
    fk.delete_referential_action AS DeleteAction,
    fk.update_referential_action AS UpdateAction
  FROM sys.foreign_keys fk
  INNER JOIN sys.tables pt ON pt.object_id = fk.parent_object_id
  INNER JOIN sys.schemas ps ON ps.schema_id = pt.schema_id
  INNER JOIN sys.tables rt ON rt.object_id = fk.referenced_object_id
  INNER JOIN sys.schemas rs ON rs.schema_id = rt.schema_id
  WHERE ps.name = N'ATAPUtilities' AND rs.name = N'ATAPUtilities'
),
target_fks AS (
  SELECT
    pt.name AS ParentTable,
    COALESCE(STUFF((
      SELECT N'|' + pc.name
      FROM sys.foreign_key_columns fkc2
      INNER JOIN sys.columns pc ON pc.object_id = fkc2.parent_object_id AND pc.column_id = fkc2.parent_column_id
      WHERE fkc2.constraint_object_id = fk.object_id
      ORDER BY fkc2.constraint_column_id
      FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N''), N'') AS ParentColumns,
    rt.name AS ReferencedTable,
    COALESCE(STUFF((
      SELECT N'|' + rc.name
      FROM sys.foreign_key_columns fkc3
      INNER JOIN sys.columns rc ON rc.object_id = fkc3.referenced_object_id AND rc.column_id = fkc3.referenced_column_id
      WHERE fkc3.constraint_object_id = fk.object_id
      ORDER BY fkc3.constraint_column_id
      FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N''), N'') AS ReferencedColumns,
    fk.delete_referential_action AS DeleteAction,
    fk.update_referential_action AS UpdateAction
  FROM sys.foreign_keys fk
  INNER JOIN sys.tables pt ON pt.object_id = fk.parent_object_id
  INNER JOIN sys.schemas ps ON ps.schema_id = pt.schema_id
  INNER JOIN sys.tables rt ON rt.object_id = fk.referenced_object_id
  INNER JOIN sys.schemas rs ON rs.schema_id = rt.schema_id
  WHERE ps.name = N'AceCommander' AND rs.name = N'AceCommander'
)
SELECT COUNT(*)
FROM (
  SELECT ParentTable, ParentColumns, ReferencedTable, ReferencedColumns, DeleteAction, UpdateAction
  FROM target_fks
  EXCEPT
  SELECT ParentTable, ParentColumns, ReferencedTable, ReferencedColumns, DeleteAction, UpdateAction
  FROM source_fks
) a;
'@)

    $missingTablesCount | Should -Be 0
    $extraTablesCount | Should -Be 0
    $missingIndexCount | Should -Be 0
    $extraIndexCount | Should -Be 0
    $missingFkCount | Should -Be 0
    $extraFkCount | Should -Be 0
  }

  It 'validates the first (earliest inserted) AceCommander user row matches ATAPUtilities user info payloads' {
    $firstUserQuery = @'
;WITH src AS (
  SELECT TOP (1)
    p.CreatedAt,
    u.PhiloteId,
    u.UserId,
    u.SaltedAndHashedPassword,
    u.EmailHash,
    u.HashAlgorithmName,
    master.dbo.fn_varbintohexstr(ui.FirstName) AS FirstNameHex,
    master.dbo.fn_varbintohexstr(ui.LastName)  AS LastNameHex,
    master.dbo.fn_varbintohexstr(ui.Email)     AS EmailHex,
    master.dbo.fn_varbintohexstr(ui.Phone)     AS PhoneHex,
    master.dbo.fn_varbintohexstr(ui.Role)      AS RoleHex,
    ui.EncryptionKeyVersion,
    us.PreferredTheme,
    us.IsDarkMode,
    us.Language
  FROM ATAPUtilities.[User] u
  INNER JOIN ATAPUtilities.Philote p ON p.PhiloteId = u.PhiloteId
  LEFT JOIN ATAPUtilities.UserInformation ui ON ui.UserId = u.UserId
  LEFT JOIN ATAPUtilities.UserSettings us ON us.UserId = u.UserId
  ORDER BY p.CreatedAt ASC, u.PhiloteId ASC
),
tgt AS (
  SELECT TOP (1)
    p.CreatedAt,
    u.PhiloteId,
    u.UserId,
    u.SaltedAndHashedPassword,
    u.EmailHash,
    u.HashAlgorithmName,
    master.dbo.fn_varbintohexstr(ui.FirstName) AS FirstNameHex,
    master.dbo.fn_varbintohexstr(ui.LastName)  AS LastNameHex,
    master.dbo.fn_varbintohexstr(ui.Email)     AS EmailHex,
    master.dbo.fn_varbintohexstr(ui.Phone)     AS PhoneHex,
    master.dbo.fn_varbintohexstr(ui.Role)      AS RoleHex,
    ui.EncryptionKeyVersion,
    us.PreferredTheme,
    us.IsDarkMode,
    us.Language
  FROM AceCommander.[User] u
  INNER JOIN AceCommander.Philote p ON p.PhiloteId = u.PhiloteId
  LEFT JOIN AceCommander.UserInformation ui ON ui.UserId = u.UserId
  LEFT JOIN AceCommander.UserSettings us ON us.UserId = u.UserId
  ORDER BY p.CreatedAt ASC, u.PhiloteId ASC
)
SELECT
  src.CreatedAt AS SourceCreatedAt,
  tgt.CreatedAt AS TargetCreatedAt,
  src.PhiloteId AS SourcePhiloteId,
  tgt.PhiloteId AS TargetPhiloteId,
  src.UserId AS SourceUserId,
  tgt.UserId AS TargetUserId,
  src.SaltedAndHashedPassword AS SourceSaltedAndHashedPassword,
  tgt.SaltedAndHashedPassword AS TargetSaltedAndHashedPassword,
  src.EmailHash AS SourceEmailHash,
  tgt.EmailHash AS TargetEmailHash,
  src.HashAlgorithmName AS SourceHashAlgorithmName,
  tgt.HashAlgorithmName AS TargetHashAlgorithmName,
  src.FirstNameHex AS SourceFirstNameHex,
  tgt.FirstNameHex AS TargetFirstNameHex,
  src.LastNameHex AS SourceLastNameHex,
  tgt.LastNameHex AS TargetLastNameHex,
  src.EmailHex AS SourceEmailHex,
  tgt.EmailHex AS TargetEmailHex,
  src.PhoneHex AS SourcePhoneHex,
  tgt.PhoneHex AS TargetPhoneHex,
  src.RoleHex AS SourceRoleHex,
  tgt.RoleHex AS TargetRoleHex,
  src.EncryptionKeyVersion AS SourceEncryptionKeyVersion,
  tgt.EncryptionKeyVersion AS TargetEncryptionKeyVersion,
  src.PreferredTheme AS SourcePreferredTheme,
  tgt.PreferredTheme AS TargetPreferredTheme,
  src.IsDarkMode AS SourceIsDarkMode,
  tgt.IsDarkMode AS TargetIsDarkMode,
  src.Language AS SourceLanguage,
  tgt.Language AS TargetLanguage
FROM src
CROSS JOIN tgt;
'@

    $sourceUserCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query 'SELECT COUNT(*) FROM ATAPUtilities.[User];' -As SingleValue -EnableException -ErrorAction Stop)
    $targetUserCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query 'SELECT COUNT(*) FROM AceCommander.[User];' -As SingleValue -EnableException -ErrorAction Stop)

    if ($sourceUserCount -eq 0 -or $targetUserCount -eq 0) {
      Set-ItResult -Skipped -Because "User parity precondition not met (ATAPUtilities.User count=$sourceUserCount, AceCommander.User count=$targetUserCount). Run user data migrations before this test."
      return
    }

    $rows = @(Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $firstUserQuery -As PSObject -EnableException -ErrorAction Stop)

    $rows.Count | Should -BeGreaterThan 0

    $row = $rows[0]

    $row.SourceCreatedAt | Should -Be $row.TargetCreatedAt

    $row.SourceSaltedAndHashedPassword | Should -Be $row.TargetSaltedAndHashedPassword
    $row.SourceEmailHash | Should -Be $row.TargetEmailHash
    $row.SourceHashAlgorithmName | Should -Be $row.TargetHashAlgorithmName

    $row.SourceFirstNameHex | Should -Be $row.TargetFirstNameHex
    $row.SourceLastNameHex | Should -Be $row.TargetLastNameHex
    $row.SourceEmailHex | Should -Be $row.TargetEmailHex
    $row.SourcePhoneHex | Should -Be $row.TargetPhoneHex
    $row.SourceRoleHex | Should -Be $row.TargetRoleHex
    $row.SourceEncryptionKeyVersion | Should -Be $row.TargetEncryptionKeyVersion

    $row.SourcePreferredTheme | Should -Be $row.TargetPreferredTheme
    $row.SourceIsDarkMode | Should -Be $row.TargetIsDarkMode
    $row.SourceLanguage | Should -Be $row.TargetLanguage

    # Ensure identity namespaces differ between schemas.
    $row.SourcePhiloteId | Should -Not -Be $row.TargetPhiloteId
    $row.SourceUserId | Should -Not -Be $row.TargetUserId
  }
}
