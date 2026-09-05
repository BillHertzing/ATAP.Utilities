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
    $dynamicBodies.Count|Should -Be 18
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
  It 'enforces safe HTTPS origin evidence without folding case-sensitive paths' {
    $body=@($dynamicBodies|Where-Object{$_ -match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[ProvisionContentSummaryRepositoryV1\]'})[0]
    $body|Should -Match "LOWER\(LEFT\(@OriginInput,8\)\).+<>N'https://'"
    $body|Should -Match "CHARINDEX\(N'@',@OriginAuthority\)"
    $body|Should -Match "OriginAuthority COLLATE Latin1_General_100_BIN2 LIKE N'%\[\^A-Za-z0-9\.\-\]%'"
    $body|Should -Match "CHARINDEX\(N'\?',@OriginInput\)"
    $body|Should -Match "CHARINDEX\(N'#',@OriginInput\)"
    $body|Should -Match '@ControlCode<=31'
    $body|Should -Match "RIGHT\(LOWER\(@OriginAuthority\),4\)=N':443'"
    $body|Should -Match "N'https://'\+LOWER\(@OriginAuthority\)\+N'/'\+@OriginPath"
    $body|Should -Not -Match 'LOWER\(LTRIM\(RTRIM\(@OriginUri\)\)\)'
  }
  It 'rejects whitespace-only evidence text at every controlled close boundary' {
    foreach($name in @('AssignContentSummaryVersionTagV1','AuthorizeContentSummaryDatabasePrincipalRepositoryV1',
      'RetireContentSummaryRepositoryV1','CorrectContentSummaryRepositoryRootV1',
      'RetireContentSummaryDatabasePrincipalRepositoryAuthorizationV1')){
      $body=@($dynamicBodies|Where-Object{$_ -match "CREATE PROCEDURE \[ATAPUtilities\]\.\[$name\]"})[0]
      if($body -match '@Reason nvarchar'){$body|Should -Match "NULLIF\(LTRIM\(RTRIM\(@Reason\)\),N''\)"}
      if($body -match '@SourceReference nvarchar'){$body|Should -Match "NULLIF\(LTRIM\(RTRIM\(@SourceReference\)\),N''\)"}
    }
  }
  It 'rejects Guid.Empty for every caller-supplied durable identifier' {
    foreach($name in @(
      'ProvisionContentSummaryRepositoryV1','AssignContentSummaryVersionTagV1',
      'AuthorizeContentSummaryDatabasePrincipalRepositoryV1','RetireContentSummaryRepositoryV1',
      'CorrectContentSummaryRepositoryRootV1',
      'RetireContentSummaryDatabasePrincipalRepositoryAuthorizationV1')){
      $body=@($dynamicBodies|Where-Object{$_ -match "CREATE PROCEDURE \[ATAPUtilities\]\.\[$name\]"})[0]
      $parameters=@([regex]::Matches(($body -split "(?m)^AS\s*$",2)[0],'@(?<name>[A-Za-z0-9_]+)\s+uniqueidentifier')|
        ForEach-Object{$_.Groups['name'].Value})
      foreach($parameter in $parameters){
        $body|Should -Match ([regex]::Escape("@$parameter='00000000-0000-0000-0000-000000000000")) -Because "$name @$parameter"
      }
    }
  }
  It 'exact-replays every immutable repository origin and root registration field' {
    $body=@($dynamicBodies|Where-Object{$_ -match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[ProvisionContentSummaryRepositoryV1\]'})[0]
    foreach($token in @('r.PhiloteId=@RepositoryId','r.CreatedAtUtc=@RecordedAtUtc',
      'r.SourceReference=N''CS-PROVISION-V1''','pv.ValidFromUtc=@RecordedAtUtc',
      'o.RecordedAtUtc=@RecordedAtUtc','rr.NormalizedRoot=@Root','rr.RegisteredAtUtc=@RecordedAtUtc',
      'rr.RegistrarEntityId=@PrincipalId','rr.EvidenceEntityId=@EvidenceEntityId',
      'rr.RecordedAtUtc=@RecordedAtUtc','rc.RecordedAtUtc=@RecordedAtUtc')){
      $body|Should -Match ([regex]::Escape($token))
    }
  }
  It 'makes root correction an exact replay before active-prior rejection' {
    $body=@($dynamicBodies|Where-Object{$_ -match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[CorrectContentSummaryRepositoryRootV1\]'})[0]
    $replay=$body.IndexOf('WHERE CorrectionId=@CorrectionId',[StringComparison]::Ordinal)
    $activePrior=$body.IndexOf('active prior root does not exist',[StringComparison]::Ordinal)
    $replay|Should -BeGreaterThan -1
    $activePrior|Should -BeGreaterThan $replay
    foreach($token in @('c.RepositoryId=@RepositoryId','c.Reason=@Reason','priorRoot.RetiredAtUtc=@RecordedAtUtc',
      'successorRoot.NormalizedRoot=@Root','canonicalRoot.CanonicalWindowsRoot=@Root',"CAST('Existing' AS varchar(16))")){
      $body|Should -Match ([regex]::Escape($token))
    }
  }
  It 'requires immutable evidence for direct repository and authorization closes' {
    foreach($token in @(
      'ContentSummaryRepositoryRetirementEvidence','ContentSummaryAuthorizationRetirementEvidence',
      'TR_ContentSummaryRepositoryRetirementEvidence_Immutable','TR_ContentSummaryAuthorizationRetirementEvidence_Immutable',
      'Repository close requires matching immutable retirement evidence',
      'Authorization close requires matching immutable retirement evidence',
      'repository retirement cannot leave an active root',
      'retirement replay conflicts with immutable close evidence')){
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
  It 'has no trailing blank line' {
    $migration|Should -Not -Match "(?:\r?\n){2}$"
  }
}
