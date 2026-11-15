#Requires -Version 7.0
# Unit tests for the private rehearsal boundary contract loader (Impl-Rehearsal-Parameterize, Phase A).
BeforeAll {
  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:repoRoot = [IO.Path]::GetFullPath((Join-Path $script:moduleRoot '../..'))
  . (Join-Path $script:moduleRoot 'private/Read-RehearsalBoundaryContract.ps1')
  $script:realContract = Join-Path $script:repoRoot 'Database/Verify/RehearsalBoundaries.json'
  $script:realNames = @(Get-ChildItem -LiteralPath (Join-Path $script:repoRoot 'Database/Flyway/SQL') -Filter 'V*.sql' -File | ForEach-Object Name)

  function New-SyntheticContract {
    param([scriptblock]$Mutate)
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path (Join-Path $root 'AceCommander') -Force
    $verifierHashes = @{}
    foreach ($name in @('Login.sql', 'Decrypt.sql', 'Org.sql', 'Role.sql')) {
      $path = Join-Path $root "AceCommander/$name"
      [IO.File]::WriteAllText($path, "SELECT N'$name' AS FixturePhase;`n", [Text.UTF8Encoding]::new($false))
      $verifierHashes[$name] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    $contract = [ordered]@{
      schemaVersion = 1; packageId = 'Synthetic.Database'; sourceDatabaseName = 'Synthetic'
      floor = [ordered]@{ version = '00140'; migrationCount = 2 }
      boundaries = @(
        [ordered]@{ version = '00150'; kind = 'Plain'; newMigrations = @('V00150__P.sql') }
        [ordered]@{ version = '00170'; kind = 'LoginDecrypt'; newMigrations = @('V00160__L.sql', 'V00170__D.sql')
          verifiers = @([ordered]@{ role = 'Login'; path = 'AceCommander/Login.sql'; sha256 = $verifierHashes['Login.sql'] },
            [ordered]@{ role = 'Decrypt'; path = 'AceCommander/Decrypt.sql'; sha256 = $verifierHashes['Decrypt.sql'] }) }
        [ordered]@{ version = '00210'; kind = 'BeforeAfter'; phaseTag = '210'; sessionContextKey = 'ATAP.Org210.ExpectedCatalog'
          newMigrations = @('V00180__A.sql', 'V00210__B.sql')
          verifiers = @([ordered]@{ role = 'BeforeAfter'; path = 'AceCommander/Org.sql'; sha256 = $verifierHashes['Org.sql'] }) }
        [ordered]@{ version = '00220'; kind = 'BeforeAfter'; sessionContextKey = 'ATAP.Role220.ExpectedCatalog'
          newMigrations = @('V00220__R.sql')
          verifiers = @([ordered]@{ role = 'BeforeAfter'; path = 'AceCommander/Role.sql'; sha256 = $verifierHashes['Role.sql'] }) }
      )
      admittedBaselines = @('00140', '00150', '00170', '00210', '00220')
    }
    if ($Mutate) { & $Mutate $contract $root }
    $contractPath = Join-Path $root 'RehearsalBoundaries.json'
    [IO.File]::WriteAllText($contractPath, ($contract | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    return $contractPath
  }
  $script:syntheticNames = @('V00010__A.sql', 'V00140__F.sql', 'V00150__P.sql', 'V00160__L.sql', 'V00170__D.sql', 'V00180__A.sql', 'V00210__B.sql', 'V00220__R.sql')
}

Describe 'Read-RehearsalBoundaryContract' -Tag 'Unit' {
  BeforeEach { Mock Write-PSFMessage {} }

  Context 'the committed contract' {
    It 'accepts the repository contract and resolves the package head 00220' {
      $result = Read-RehearsalBoundaryContract -Path $script:realContract -MigrationNames $script:realNames
      $result.PackageId | Should -BeExactly 'ATAPUtilities.Database'
      $result.SourceDatabaseName | Should -BeExactly 'ATAPUtilities'
      $result.TargetVersion | Should -BeExactly '00220'
      $result.MigrationVersions.Count | Should -Be $script:realNames.Count
      ($result.Boundaries.Version -join ',') | Should -BeExactly '00150,00170,00210,00220'
      ($result.AdmittedBaselines -join ',') | Should -BeExactly '00140,00150,00170,00210,00220'
      foreach ($verifier in @($result.Boundaries.Verifiers)) {
        (Get-FileHash -LiteralPath $verifier.Path -Algorithm SHA256).Hash | Should -BeExactly $verifier.Sha256
        $verifier.Path | Should -BeLike ([IO.Path]::GetFullPath((Join-Path $script:repoRoot 'Database/Verify')) + '*')
      }
    }
    It 'still resolves a 0.1.25-shaped package (through V00210) to target 00210' {
      $names = @($script:realNames | Where-Object { $_ -notlike 'V00220__*' })
      (Read-RehearsalBoundaryContract -Path $script:realContract -MigrationNames $names).TargetVersion | Should -BeExactly '00210'
    }
    It 'pins the historical Login/Decrypt verifier hashes that the private sequence defaults to' {
      $sequenceText = Get-Content -LiteralPath (Join-Path $script:moduleRoot 'private/Invoke-AceCommanderLoginFixtureSequence.ps1') -Raw
      $result = Read-RehearsalBoundaryContract -Path $script:realContract
      foreach ($verifier in @(($result.Boundaries | Where-Object Kind -CEQ 'LoginDecrypt').Verifiers)) {
        $sequenceText | Should -Match ([regex]::Escape("'$($verifier.Sha256)'"))
      }
    }
    It 'keeps the V00210 session key that Verify_Organization_V00210.sql reads' {
      $result = Read-RehearsalBoundaryContract -Path $script:realContract
      foreach ($boundary in @($result.Boundaries | Where-Object Kind -CEQ 'BeforeAfter')) {
        $boundary.Verifiers[0].Text | Should -Match ([regex]::Escape("SESSION_CONTEXT(N'$($boundary.SessionContextKey)')"))
        $boundary.Verifiers[0].Text | Should -Match ([regex]::Escape("N'Before$($boundary.PhaseTag)'"))
        $boundary.Verifiers[0].Text | Should -Match ([regex]::Escape("N'After$($boundary.PhaseTag)'"))
      }
    }
  }

  Context 'synthetic contract structure' {
    It 'accepts a valid synthetic contract and defaults phaseTag to the integer version' {
      $result = Read-RehearsalBoundaryContract -Path (New-SyntheticContract) -MigrationNames $script:syntheticNames
      $result.TargetVersion | Should -BeExactly '00220'
      ($result.Boundaries | Where-Object Version -CEQ '00220').PhaseTag | Should -BeExactly '220'
      ($result.Boundaries | Where-Object Version -CEQ '00150').PhaseTag | Should -BeExactly '150'
    }
    It 'refuses a relative or padded path' {
      { Read-RehearsalBoundaryContract -Path 'Database/Verify/RehearsalBoundaries.json' } | Should -Throw '*absolute and trim-exact*'
      { Read-RehearsalBoundaryContract -Path ($script:realContract + ' ') } | Should -Throw '*absolute and trim-exact*'
    }
    It 'refuses a missing contract' {
      { Read-RehearsalBoundaryContract -Path (Join-Path $TestDrive 'absent.json') } | Should -Throw '*not found*'
    }
    It 'refuses invalid JSON' {
      $path = Join-Path $TestDrive 'bad.json'; [IO.File]::WriteAllText($path, '{ not json')
      { Read-RehearsalBoundaryContract -Path $path } | Should -Throw '*not valid JSON*'
    }
    It 'refuses <Label>' -ForEach @(
      @{ Label = 'an unknown root property'; Expect = '*unknown property*'; Mutate = { param($c) $c.extra = 1 } }
      @{ Label = 'schemaVersion 2'; Expect = '*schemaVersion*'; Mutate = { param($c) $c.schemaVersion = 2 } }
      @{ Label = 'a string schemaVersion'; Expect = '*schemaVersion*'; Mutate = { param($c) $c.schemaVersion = '1' } }
      @{ Label = 'a blank packageId'; Expect = '*packageId*'; Mutate = { param($c) $c.packageId = ' ' } }
      @{ Label = 'an unsafe source catalog'; Expect = '*sourceDatabaseName*'; Mutate = { param($c) $c.sourceDatabaseName = 'A;B' } }
      @{ Label = 'unsorted boundaries'; Expect = '*strictly ascending*'; Mutate = { param($c) $c.boundaries = @($c.boundaries[1], $c.boundaries[0]) + @($c.boundaries[2..3]) } }
      @{ Label = 'a boundary at the floor'; Expect = '*strictly ascending*'; Mutate = { param($c) $c.boundaries[0].version = '00140'; $c.boundaries[0].newMigrations = @('V00140__X.sql') } }
      @{ Label = 'an unknown kind'; Expect = '*not a known kind*'; Mutate = { param($c) $c.boundaries[0].kind = 'plain' } }
      @{ Label = 'empty newMigrations'; Expect = '*nonempty array*'; Mutate = { param($c) $c.boundaries[0].newMigrations = @() } }
      @{ Label = 'newMigrations that do not end at the boundary'; Expect = '*must end with*'; Mutate = { param($c) $c.boundaries[2].newMigrations = @('V00180__A.sql', 'V00200__B.sql') } }
      @{ Label = 'newMigrations above the boundary'; Expect = '*must ascend*'; Mutate = { param($c) $c.boundaries[0].newMigrations = @('V00160__P.sql') } }
      @{ Label = 'a BeforeAfter boundary without a session key'; Expect = '*requires sessionContextKey*'; Mutate = { param($c) $c.boundaries[3].Remove('sessionContextKey') } }
      @{ Label = 'a duplicated session key'; Expect = '*not unique*'; Mutate = { param($c) $c.boundaries[3].sessionContextKey = 'ATAP.Org210.ExpectedCatalog' } }
      @{ Label = 'a malformed session key'; Expect = '*ATAP.<Name>.ExpectedCatalog*'; Mutate = { param($c) $c.boundaries[3].sessionContextKey = "x'; DROP" } }
      @{ Label = 'a session key on a Plain boundary'; Expect = '*only valid for BeforeAfter*'; Mutate = { param($c) $c.boundaries[0].sessionContextKey = 'ATAP.P.ExpectedCatalog' } }
      @{ Label = 'LoginDecrypt verifiers in the wrong order'; Expect = '*verifier roles*'; Mutate = { param($c) $c.boundaries[1].verifiers = @($c.boundaries[1].verifiers[1], $c.boundaries[1].verifiers[0]) } }
      @{ Label = 'a Plain boundary with a verifier'; Expect = '*verifier roles*'; Mutate = { param($c) $c.boundaries[0].verifiers = @($c.boundaries[2].verifiers[0]) } }
      @{ Label = 'a verifier path escaping the folder'; Expect = '*plain relative path*'; Mutate = { param($c) $c.boundaries[3].verifiers[0].path = '../Role.sql' } }
      @{ Label = 'a rooted verifier path'; Expect = '*plain relative path*'; Mutate = { param($c) $c.boundaries[3].verifiers[0].path = 'C:/Windows/win.ini' } }
      @{ Label = 'a verifier SHA-256 mismatch'; Expect = '*does not match its SHA-256 pin*'; Mutate = { param($c) $c.boundaries[3].verifiers[0].sha256 = ('0' * 64) } }
      @{ Label = 'a lowercase SHA-256 pin'; Expect = '*uppercase hex*'; Mutate = { param($c) $c.boundaries[3].verifiers[0].sha256 = $c.boundaries[3].verifiers[0].sha256.ToLowerInvariant() } }
      @{ Label = 'a missing verifier file'; Expect = '*is missing*'; Mutate = { param($c, $root) Remove-Item -LiteralPath (Join-Path $root 'AceCommander/Role.sql') } }
      @{ Label = 'a verifier reused by two boundaries'; Expect = '*used more than once*'; Mutate = { param($c) $c.boundaries[3].verifiers[0] = $c.boundaries[2].verifiers[0] } }
      @{ Label = 'an admitted baseline that is not a boundary'; Expect = '*neither the floor nor a boundary*'; Mutate = { param($c) $c.admittedBaselines = @('00140', '00160') } }
      @{ Label = 'a duplicated admitted baseline'; Expect = '*duplicated*'; Mutate = { param($c) $c.admittedBaselines = @('00140', '00140') } }
    ) {
      { Read-RehearsalBoundaryContract -Path (New-SyntheticContract -Mutate $Mutate) } | Should -Throw $Expect
    }
  }

  Context 'package migration names' {
    It 'resolves an earlier head when the package stops at an earlier boundary' {
      $names = @($script:syntheticNames | Where-Object { $_ -notlike 'V00220__*' -and $_ -notlike 'V002?0__B*' -and $_ -notlike 'V00180__*' })
      (Read-RehearsalBoundaryContract -Path (New-SyntheticContract) -MigrationNames $names).TargetVersion | Should -BeExactly '00170'
    }
    It 'refuses <Label>' -ForEach @(
      @{ Label = 'a head that is not a boundary'; Expect = '*does not support this manifest migration boundary*'; Names = @('V00010__A.sql', 'V00140__F.sql', 'V00150__P.sql', 'V00160__L.sql', 'V00170__D.sql', 'V00180__A.sql', 'V00210__B.sql', 'V00220__R.sql', 'V00230__Z.sql') }
      @{ Label = 'a missing middle migration'; Expect = '*not exactly the contract boundary migrations*'; Names = @('V00010__A.sql', 'V00140__F.sql', 'V00150__P.sql', 'V00170__D.sql', 'V00180__A.sql', 'V00210__B.sql', 'V00220__R.sql') }
      @{ Label = 'an extra migration inside a boundary'; Expect = '*not exactly the contract boundary migrations*'; Names = @('V00010__A.sql', 'V00140__F.sql', 'V00150__P.sql', 'V00160__L.sql', 'V00170__D.sql', 'V00180__A.sql', 'V00190__X.sql', 'V00210__B.sql', 'V00220__R.sql') }
      @{ Label = 'a renamed boundary migration'; Expect = '*not exactly the contract boundary migrations*'; Names = @('V00010__A.sql', 'V00140__F.sql', 'V00150__P.sql', 'V00160__L.sql', 'V00170__D.sql', 'V00180__A.sql', 'V00210__B.sql', 'V00220__Renamed.sql') }
      @{ Label = 'a wrong count through the floor'; Expect = '*exactly 2 migrations through the floor*'; Names = @('V00010__A.sql', 'V00020__B.sql', 'V00140__F.sql', 'V00150__P.sql', 'V00160__L.sql', 'V00170__D.sql', 'V00180__A.sql', 'V00210__B.sql', 'V00220__R.sql') }
      @{ Label = 'no floor migration'; Expect = '*through the floor*'; Names = @('V00010__A.sql', 'V00130__F.sql', 'V00150__P.sql', 'V00160__L.sql', 'V00170__D.sql', 'V00180__A.sql', 'V00210__B.sql', 'V00220__R.sql') }
      @{ Label = 'a duplicated version'; Expect = '*unique and ascending*'; Names = @('V00010__A.sql', 'V00140__F.sql', 'V00140__G.sql', 'V00150__P.sql') }
      @{ Label = 'a non-versioned file name'; Expect = '*not a versioned migration file name*'; Names = @('V00010__A.sql', 'R__Repeatable.sql') }
    ) {
      { Read-RehearsalBoundaryContract -Path (New-SyntheticContract) -MigrationNames $Names } | Should -Throw $Expect
    }
    It 'refuses an empty migration name list' {
      { Read-RehearsalBoundaryContract -Path (New-SyntheticContract) -MigrationNames @() } | Should -Throw
    }
  }
}
