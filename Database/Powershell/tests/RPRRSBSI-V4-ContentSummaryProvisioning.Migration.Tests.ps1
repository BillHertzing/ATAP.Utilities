#Requires -Version 7.0
#Requires -Module Pester
Set-StrictMode -Version Latest

Describe 'V00120 ContentSummary provisioning migration' {
  BeforeAll {
    $repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $flywayRoot=Join-Path $repoRoot 'Database\Flyway'
    $sqlDirectory=Join-Path $flywayRoot 'SQL'
    $migration=Get-Content -Raw -LiteralPath (Join-Path $sqlDirectory 'V00120__Add_ContentSummary_Provisioning_And_Correction.sql')
    $dynamicBodies=@([regex]::Matches($migration,"(?s)EXEC\s+sys\.sp_executesql\s+N'(?<body>(?:''|[^'])*)';")|
      ForEach-Object{$_.Groups['body'].Value.Replace("''","'")})
    $dll='C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
    if(-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])){Add-Type -LiteralPath $dll}
  }
  It 'parses the outer migration and all dynamic batches' {
    $parser=[Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    $dynamicBodies.Count|Should -Be 16
    foreach($batch in @($migration)+$dynamicBodies){
      $reader=[IO.StringReader]::new($batch)
      $errors=[Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
      try{$null=$parser.Parse($reader,[ref]$errors)}finally{$reader.Dispose()}
      @($errors|ForEach-Object{"Line $($_.Line), column $($_.Column): $($_.Message)"})|Should -BeNullOrEmpty
    }
  }
  It 'preserves V00100 and V00110 and allocates only V00120 next' {
    (Get-FileHash (Join-Path $sqlDirectory 'V00100__Create_ATAPUtilities_ContentSummary_And_Query.sql') -Algorithm SHA256).Hash|
      Should -Be '0C2CD88699304D7CC9EF10303CFB4900969159A4A2E90B52C2A175AA1C69262C'
    (Get-FileHash (Join-Path $sqlDirectory 'V00110__Create_ContentSummary_DAB_Principal_Facade.sql') -Algorithm SHA256).Hash|
      Should -Be '2AF141C60C16551DE54696B2A9DC20F91D6B6416C029A6B2F80722857FED38B4'
    @((Get-ChildItem $sqlDirectory -File -Filter 'V001*.sql').Name)|Should -Be @(
      'V00100__Create_ATAPUtilities_ContentSummary_And_Query.sql',
      'V00110__Create_ContentSummary_DAB_Principal_Facade.sql',
      'V00120__Add_ContentSummary_Provisioning_And_Correction.sql')
  }
  It 'freezes the adapter procedure names and ordered parameters' {
    $expected=[ordered]@{
      ProvisionContentSummaryRepositoryV1=@('RepositoryId','RepositoryRootRegistrationId','CanonicalRepositoryName','OriginUri','CanonicalRoot','RootKindCode','OrganizationId','ClassificationPolicyId','PrincipalId','EvidenceEntityId','RecordedAtUtc')
      AssignContentSummaryVersionTagV1=@('TagId','TagAssignmentId','ContentSummaryVersionId','PrincipalId','SourceReference','RecordedAtUtc')
      AuthorizeContentSummaryDatabasePrincipalRepositoryV1=@('AuthorizationId','DatabasePrincipalName','InstanceCode','RepositoryId','SourceReference','RecordedAtUtc')
    }
    foreach($entry in $expected.GetEnumerator()){
      $body=@($dynamicBodies|Where-Object{$_ -match "CREATE PROCEDURE \[ATAPUtilities\]\.\[$($entry.Key)\]"})
      $body.Count|Should -Be 1
      $header=($body[0] -split "(?m)^AS\s*$",2)[0]
      @([regex]::Matches($header,'@(?<name>[A-Za-z0-9_]+)\s+')|ForEach-Object{$_.Groups['name'].Value})|
        Should -Be $entry.Value
    }
    $migration|Should -Not -Match 'CREATE OR ALTER PROCEDURE \[ATAPUtilities\]\.\[CaptureContentSummaryObservationV1\]'
  }
  It 'uses five immutable Philote-backed operational identity kinds and a distinct prompt RuleVariant' {
    foreach($kind in @('Organization','ClassificationPolicy','PrincipalRegistrar','Evidence','Harvester')){
      $migration|Should -Match ([regex]::Escape("'$kind'"))
    }
    $migration|Should -Match 'TR_ContentSummaryOperationalIdentity_Immutable'
    $migration|Should -Match 'CS-R07-safe-summary-prompt-v1'
    $migration|Should -Match "PromptRuleVariantId<>''b1200000-0000-0000-0000-000000000201''"
    $migration|Should -Match "IdentityKindCode=''Harvester''"
  }
  It 'canonicalizes root aliases and uses append-close correction' {
    $migration|Should -Match 'LOWER\(REPLACE\(LTRIM\(RTRIM\(@CanonicalRoot\)'
    $migration|Should -Match 'CanonicalWindowsRootSha256'
    foreach($token in @('Repository is append/close-only','Repository root registration is append/close-only',
      'ContentSummary principal authorization is append/close-only','RetireContentSummaryRepositoryV1',
      'CorrectContentSummaryRepositoryRootV1','RetireContentSummaryDatabasePrincipalRepositoryAuthorizationV1')){
      $migration|Should -Match ([regex]::Escape($token))
    }
  }
  It 'assigns only an existing effective Tag to a ContentSummaryVersion' {
    $body=@($dynamicBodies|Where-Object{$_ -match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[AssignContentSummaryVersionTagV1\]'})[0]
    $body|Should -Match "EntityTypeCode=N'content-summary-version'"
    $body|Should -Match 'ResolveTagAsOf'
    $body|Should -Match 'TagNamespaceSteward'
    $body|Should -Not -Match 'INSERT INTO \[ATAPUtilities\]\.\[Tag\]'
  }
  It 'grants the provisioner execute only and creates no user or membership' {
    $migration|Should -Match 'CREATE ROLE \[ATAPContentSummaryProvisioner\]'
    @([regex]::Matches($migration,'(?im)^\s*GRANT EXECUTE ON OBJECT::')).Count|Should -Be 6
    $migration|Should -Match 'DENY SELECT, INSERT, UPDATE, DELETE, ALTER, REFERENCES, VIEW DEFINITION'
    $migration|Should -Not -Match '(?im)^\s*CREATE\s+(?:LOGIN|USER)\b'
    $migration|Should -Not -Match '(?im)^\s*ALTER\s+ROLE.+ADD\s+MEMBER'
  }
  It 'binds package 0.1.11 to every migration and seed byte' {
    $version=Get-Content -Raw (Join-Path $flywayRoot 'version.json')|ConvertFrom-Json
    $allowlist=Get-Content -Raw (Join-Path $flywayRoot 'package-content-allowlist.json')|ConvertFrom-Json -Depth 10
    $expectedPaths=@(
      @(Get-ChildItem $sqlDirectory -File -Filter 'V*.sql'|Sort-Object Name|ForEach-Object{'SQL/'+$_.Name})
      @(Get-ChildItem (Join-Path $flywayRoot 'Data') -File -Filter '*.csv'|Sort-Object Name|ForEach-Object{'Data/'+$_.Name}))
    $version.version|Should -Be '0.1.11'
    $allowlist.sourceVersion|Should -Be $version.version
    @($allowlist.files.path)|Should -Be $expectedPaths
    foreach($entry in $allowlist.files){
      $path=Join-Path $flywayRoot ($entry.path -replace '/',[IO.Path]::DirectorySeparatorChar)
      (Get-FileHash $path -Algorithm SHA256).Hash|Should -Be $entry.sha256 -Because $entry.path
    }
  }
}

