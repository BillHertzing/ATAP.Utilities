# AI assisted using pesterTest.instructions.md as guidelines

$SqlInstance = if ($env:ATAPUTILITIES_SQLINSTANCE) { $env:ATAPUTILITIES_SQLINSTANCE } else { 'localhost' }
$DatabaseName = 'ATAPUtilities'

Describe 'User view existence and structure' {
  BeforeAll {
    if (-not (Get-Module -ListAvailable -Name dbatools)) {
      throw 'dbatools module is required for this test. Install-Module dbatools -Scope CurrentUser'
    }

    Import-Module dbatools -ErrorAction Stop

    Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig | Out-Null
    Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig | Out-Null
  }

  It 'ATAPUtilities.vw_UserFull exists' {
    $count = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query @'
SELECT COUNT(*)
FROM sys.views v
INNER JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = N'ATAPUtilities' AND v.name = N'vw_UserFull';
'@)
    $count | Should -Be 1
  }

  It 'AceCommander.vw_UserFull exists' {
    $count = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query @'
SELECT COUNT(*)
FROM sys.views v
INNER JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = N'AceCommander' AND v.name = N'vw_UserFull';
'@)
    $count | Should -Be 1
  }

  It 'AceCommander.vw_UserCrossSchema exists' {
    $count = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query @'
SELECT COUNT(*)
FROM sys.views v
INNER JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = N'AceCommander' AND v.name = N'vw_UserCrossSchema';
'@)
    $count | Should -Be 1
  }

  It 'ATAPUtilities.vw_UserFull contains expected columns' {
    $expectedColumns = @('UserId', 'EmailHash', 'HashAlgorithmName', 'FirstName', 'LastName', 'Email', 'Phone', 'Role', 'EncryptionKeyVersion', 'PreferredTheme', 'IsDarkMode', 'Language')

    $actualColumns = @(Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As PSObject -EnableException -ErrorAction Stop -Query @'
SELECT c.name AS ColumnName
FROM sys.columns c
INNER JOIN sys.views v ON v.object_id = c.object_id
INNER JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = N'ATAPUtilities' AND v.name = N'vw_UserFull'
ORDER BY c.column_id;
'@ | Select-Object -ExpandProperty ColumnName)

    foreach ($col in $expectedColumns) {
      $actualColumns | Should -Contain $col
    }
  }

  It 'AceCommander.vw_UserFull contains expected columns' {
    $expectedColumns = @('UserId', 'EmailHash', 'HashAlgorithmName', 'FirstName', 'LastName', 'Email', 'Phone', 'Role', 'EncryptionKeyVersion', 'PreferredTheme', 'IsDarkMode', 'Language')

    $actualColumns = @(Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As PSObject -EnableException -ErrorAction Stop -Query @'
SELECT c.name AS ColumnName
FROM sys.columns c
INNER JOIN sys.views v ON v.object_id = c.object_id
INNER JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = N'AceCommander' AND v.name = N'vw_UserFull'
ORDER BY c.column_id;
'@ | Select-Object -ExpandProperty ColumnName)

    foreach ($col in $expectedColumns) {
      $actualColumns | Should -Contain $col
    }
  }

  It 'AceCommander.vw_UserCrossSchema contains expected columns' {
    $expectedColumns = @(
      'EmailHash',
      'AC_UserId', 'AC_HashAlgorithmName', 'AC_FirstName', 'AC_LastName', 'AC_Email', 'AC_Phone', 'AC_Role', 'AC_EncryptionKeyVersion', 'AC_PreferredTheme', 'AC_IsDarkMode', 'AC_Language',
      'ATU_UserId', 'ATU_HashAlgorithmName', 'ATU_FirstName', 'ATU_LastName', 'ATU_Email', 'ATU_Phone', 'ATU_Role', 'ATU_EncryptionKeyVersion', 'ATU_PreferredTheme', 'ATU_IsDarkMode', 'ATU_Language'
    )

    $actualColumns = @(Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As PSObject -EnableException -ErrorAction Stop -Query @'
SELECT c.name AS ColumnName
FROM sys.columns c
INNER JOIN sys.views v ON v.object_id = c.object_id
INNER JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = N'AceCommander' AND v.name = N'vw_UserCrossSchema'
ORDER BY c.column_id;
'@ | Select-Object -ExpandProperty ColumnName)

    foreach ($col in $expectedColumns) {
      $actualColumns | Should -Contain $col
    }
  }
}

Describe 'User view query behavior' {
  BeforeAll {
    if (-not (Get-Module -ListAvailable -Name dbatools)) {
      throw 'dbatools module is required for this test. Install-Module dbatools -Scope CurrentUser'
    }

    Import-Module dbatools -ErrorAction Stop

    Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig | Out-Null
    Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig | Out-Null
  }

  It 'ATAPUtilities.vw_UserFull is queryable and returns rows when users exist' {
    $userCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query 'SELECT COUNT(*) FROM ATAPUtilities.[User];')

    if ($userCount -eq 0) {
      Set-ItResult -Skipped -Because 'No ATAPUtilities users present; run user data migrations first.'
      return
    }

    $viewCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query 'SELECT COUNT(*) FROM ATAPUtilities.vw_UserFull;')
    $viewCount | Should -Be $userCount
  }

  It 'AceCommander.vw_UserFull is queryable and returns rows when users exist' {
    $userCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query 'SELECT COUNT(*) FROM AceCommander.[User];')

    if ($userCount -eq 0) {
      Set-ItResult -Skipped -Because 'No AceCommander users present; run user data migrations first.'
      return
    }

    $viewCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query 'SELECT COUNT(*) FROM AceCommander.vw_UserFull;')
    $viewCount | Should -Be $userCount
  }

  It 'ATAPUtilities.vw_UserFull LEFT JOIN preserves User rows when UserInformation is absent' {
    # Insert an isolated user with no UserInformation or UserSettings row,
    # verify the view returns the row with NULL PII columns, then clean up.
    $testPhiloteId = [guid]::NewGuid().ToString()
    $testUserId = [guid]::NewGuid().ToString()

    Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -EnableException -ErrorAction Stop -Query @"
INSERT INTO ATAPUtilities.Philote (PhiloteId) VALUES ('$testPhiloteId');
INSERT INTO ATAPUtilities.[User]  (PhiloteId, UserId, HashAlgorithmName) VALUES ('$testPhiloteId', '$testUserId', N'Argon2id');
"@

    try {
      $row = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As PSObject -EnableException -ErrorAction Stop -Query @"
SELECT UserId, FirstName, PreferredTheme
FROM ATAPUtilities.vw_UserFull
WHERE UserId = '$testUserId';
"@

      $row | Should -Not -BeNullOrEmpty
      $row.FirstName      | Should -BeNullOrEmpty
      $row.PreferredTheme | Should -BeNullOrEmpty
    }
    finally {
      Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -EnableException -ErrorAction Stop -Query @"
DELETE FROM ATAPUtilities.[User]   WHERE UserId   = '$testUserId';
DELETE FROM ATAPUtilities.Philote  WHERE PhiloteId = '$testPhiloteId';
"@
    }
  }

  It 'AceCommander.vw_UserCrossSchema cross-schema join returns matched rows when EmailHash aligns' {
    $acUserCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query "SELECT COUNT(*) FROM AceCommander.[User] WHERE EmailHash IS NOT NULL;")
    $atuUserCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query "SELECT COUNT(*) FROM ATAPUtilities.[User] WHERE EmailHash IS NOT NULL;")

    if ($acUserCount -eq 0 -or $atuUserCount -eq 0) {
      Set-ItResult -Skipped -Because "Cross-schema join test requires users with EmailHash in both schemas (AC=$acUserCount, ATU=$atuUserCount)."
      return
    }

    $matchedCount = [int](Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As SingleValue -EnableException -ErrorAction Stop -Query @'
SELECT COUNT(*)
FROM AceCommander.vw_UserCrossSchema
WHERE ATU_UserId IS NOT NULL;
'@)
    $matchedCount | Should -BeGreaterThan 0
  }

  It 'AceCommander.vw_UserCrossSchema settings columns are clear text (not VARBINARY) for matched rows' {
    $sampleRow = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -As PSObject -EnableException -ErrorAction Stop -Query @'
SELECT TOP (1)
    AC_IsDarkMode,
    ATU_IsDarkMode
FROM AceCommander.vw_UserCrossSchema
WHERE ATU_UserId IS NOT NULL;
'@

    if (-not $sampleRow) {
      Set-ItResult -Skipped -Because 'No matched cross-schema rows available to verify clear-text settings columns.'
      return
    }

    # IsDarkMode is BIT — confirm it is not a byte array (i.e., not encrypted VARBINARY)
    $sampleRow.AC_IsDarkMode  | Should -BeOfType [bool]
    $sampleRow.ATU_IsDarkMode | Should -BeOfType [bool]
  }
}
