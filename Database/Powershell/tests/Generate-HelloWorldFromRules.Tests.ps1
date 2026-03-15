# AI assisted using Powershell.instructions.md as guidelines

$SqlInstance = if ($env:ATAPUTILITIES_SQLINSTANCE) { $env:ATAPUTILITIES_SQLINSTANCE } else { 'localhost' }
$DatabaseName = 'ATAPUtilities'
$SchemaTablesValidated = $false

Describe 'ATAPUtilities Rule schema prerequisites' {
  BeforeAll {
    if (-not (Get-Module -ListAvailable -Name dbatools)) {
      throw 'dbatools module is required for this test. Install-Module dbatools -Scope CurrentUser'
    }

    Import-Module dbatools -ErrorAction Stop

    Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig | Out-Null
    Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig | Out-Null
  }

  It 'has all required ATAPUtilities schema tables' {
    $requiredTables = @(
      'Philote'
      'PrimitiveLanguageKind'
      'Rule'
      'RuleInstantiation'
      'RuleInstantiationBinding'
    )

    $existingTableNames = @(
      Get-DbaDbTable -SqlInstance $SqlInstance -Database $DatabaseName -Schema 'ATAPUtilities' -EnableException |
      Select-Object -ExpandProperty Name
    )
    $missingTables = @($requiredTables | Where-Object { $_ -notin $existingTableNames })

    $missingTables.Count | Should -Be 0 -Because "SqlInstance=$SqlInstance; Database=$DatabaseName; ExistingTables=$($existingTableNames -join ', '); Missing required tables in ATAPUtilities schema: $($missingTables -join ', ')"
    $SchemaTablesValidated = $true
  }
}

Describe 'Generate HelloWorld artifacts from ATAPUtilities Rule tables' {
  BeforeAll {
    # Keep this block self-contained: state set in one Describe can be unavailable in another Describe under Pester discovery/runtime scoping.
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $script:GeneratedRoot = Join-Path $script:RepoRoot 'Database\_generated'
    $script:QueryPath = Join-Path $script:RepoRoot 'Database\Queries\Query_Generate_HelloWorld_From_Rules.sql'

    $script:ExpectedProgram = @(
      'using HelloWorld;'
      'Console.WriteLine(Greeter.GetMessage());'
    ) -join [Environment]::NewLine

    $script:ExpectedClass = @(
      'namespace HelloWorld;'
      ''
      'public static class Greeter'
      '{'
      '  public static string GetMessage() => "Hello, World!";'
      '}'
    ) -join [Environment]::NewLine

    $script:ExpectedCsproj = @(
      '<Project Sdk="Microsoft.NET.Sdk">'
      '  <PropertyGroup>'
      '    <OutputType>Exe</OutputType>'
      '    <TargetFramework>net8.0</TargetFramework>'
      '    <ImplicitUsings>enable</ImplicitUsings>'
      '    <Nullable>enable</Nullable>'
      '  </PropertyGroup>'
      '</Project>'
    ) -join [Environment]::NewLine

    $seedSql = @"
DECLARE @CSharpProgramRule UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111101';
DECLARE @CSharpClassRule UNIQUEIDENTIFIER   = '11111111-1111-1111-1111-111111111102';
DECLARE @MSBuildRule UNIQUEIDENTIFIER       = '11111111-1111-1111-1111-111111111103';
DECLARE @PathRule UNIQUEIDENTIFIER          = '11111111-1111-1111-1111-111111111104';

DECLARE @CSharpProgramInst UNIQUEIDENTIFIER = '22222222-2222-2222-2222-222222222201';
DECLARE @CSharpClassInst UNIQUEIDENTIFIER   = '22222222-2222-2222-2222-222222222202';
DECLARE @MSBuildInst UNIQUEIDENTIFIER       = '22222222-2222-2222-2222-222222222203';
DECLARE @PathInst UNIQUEIDENTIFIER          = '22222222-2222-2222-2222-222222222204';

DECLARE @ProgramContent NVARCHAR(MAX) = N'using HelloWorld;' + CHAR(13) + CHAR(10)
  + N'Console.WriteLine(Greeter.GetMessage());';

DECLARE @ClassContent NVARCHAR(MAX) = N'namespace HelloWorld;' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
  + N'public static class Greeter' + CHAR(13) + CHAR(10)
  + N'{' + CHAR(13) + CHAR(10)
  + N'  public static string GetMessage() => "Hello, World!";' + CHAR(13) + CHAR(10)
  + N'}';

DECLARE @ProjectContent NVARCHAR(MAX) = N'<Project Sdk="Microsoft.NET.Sdk">' + CHAR(13) + CHAR(10)
  + N'  <PropertyGroup>' + CHAR(13) + CHAR(10)
  + N'    <OutputType>Exe</OutputType>' + CHAR(13) + CHAR(10)
  + N'    <TargetFramework>net8.0</TargetFramework>' + CHAR(13) + CHAR(10)
  + N'    <ImplicitUsings>enable</ImplicitUsings>' + CHAR(13) + CHAR(10)
  + N'    <Nullable>enable</Nullable>' + CHAR(13) + CHAR(10)
  + N'  </PropertyGroup>' + CHAR(13) + CHAR(10)
  + N'</Project>';

DELETE FROM ATAPUtilities.RuleInstantiationBinding
WHERE InstantiationPhiloteId IN (@CSharpProgramInst, @CSharpClassInst, @MSBuildInst, @PathInst);

DELETE FROM ATAPUtilities.RuleInstantiation
WHERE PhiloteId IN (@CSharpProgramInst, @CSharpClassInst, @MSBuildInst, @PathInst);

DELETE FROM ATAPUtilities.[Rule]
WHERE PhiloteId IN (@CSharpProgramRule, @CSharpClassRule, @MSBuildRule, @PathRule);

DELETE FROM ATAPUtilities.Philote
WHERE PhiloteId IN (
  @CSharpProgramRule, @CSharpClassRule, @MSBuildRule, @PathRule,
  @CSharpProgramInst, @CSharpClassInst, @MSBuildInst, @PathInst
);

INSERT INTO ATAPUtilities.Philote (PhiloteId)
VALUES
  (@CSharpProgramRule), (@CSharpClassRule), (@MSBuildRule), (@PathRule),
  (@CSharpProgramInst), (@CSharpClassInst), (@MSBuildInst), (@PathInst);

INSERT INTO ATAPUtilities.[Rule] (PhiloteId, PrimitiveLanguageKindId, Name, Purpose, SourceFileReference)
VALUES
  (@CSharpProgramRule, 1, N'Example.HelloWorld.Program.cs', N'Generate Program.cs compilation unit', N'HelloWorld/Program.cs'),
  (@CSharpClassRule,   1, N'Example.HelloWorld.HelloWorld.cs', N'Generate HelloWorld.cs compilation unit', N'HelloWorld/HelloWorld.cs'),
  (@MSBuildRule,       4, N'Example.HelloWorld.HelloWorld.csproj', N'Generate HelloWorld project file', N'HelloWorld/HelloWorld.csproj'),
  (@PathRule,          6, N'Example.HelloWorld.Folder', N'Generate HelloWorld relative folder', N'HelloWorld');

INSERT INTO ATAPUtilities.RuleInstantiation (PhiloteId, RulePhiloteId, Notes)
VALUES
  (@CSharpProgramInst, @CSharpProgramRule, N'Program.cs instantiation'),
  (@CSharpClassInst,   @CSharpClassRule,   N'HelloWorld.cs instantiation'),
  (@MSBuildInst,       @MSBuildRule,       N'HelloWorld.csproj instantiation'),
  (@PathInst,          @PathRule,          N'HelloWorld folder instantiation');

INSERT INTO ATAPUtilities.RuleInstantiationBinding (InstantiationPhiloteId, InputName, InputValue)
VALUES
  (@PathInst, N'RelativePath', N'HelloWorld'),

  (@CSharpProgramInst, N'RelativePath', N'HelloWorld'),
  (@CSharpProgramInst, N'FileName', N'Program.cs'),
  (@CSharpProgramInst, N'FileContent', @ProgramContent),

  (@CSharpClassInst, N'RelativePath', N'HelloWorld'),
  (@CSharpClassInst, N'FileName', N'HelloWorld.cs'),
  (@CSharpClassInst, N'FileContent', @ClassContent),

  (@MSBuildInst, N'RelativePath', N'HelloWorld'),
  (@MSBuildInst, N'FileName', N'HelloWorld.csproj'),
  (@MSBuildInst, N'FileContent', @ProjectContent);
"@

    Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $seedSql | Out-Null

    if (Test-Path $script:GeneratedRoot) {
      Remove-Item -Path $script:GeneratedRoot -Recurse -Force
    }
    New-Item -Path $script:GeneratedRoot -ItemType Directory -Force | Out-Null

    $queryText = Get-Content -Path $script:QueryPath -Raw
    $script:Artifacts = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $queryText -As PSObject

    foreach ($artifact in $script:Artifacts) {
      $relativePath = $artifact.RelativePath
      if ([string]::IsNullOrWhiteSpace($relativePath)) {
        continue
      }

      $targetDirectory = Join-Path $script:GeneratedRoot $relativePath
      if (-not (Test-Path $targetDirectory)) {
        New-Item -Path $targetDirectory -ItemType Directory -Force | Out-Null
      }

      if ($artifact.ItemType -eq 'File') {
        $targetFile = Join-Path $targetDirectory $artifact.FileName
        Set-Content -Path $targetFile -Value $artifact.FileContent -Encoding utf8
      }
    }
  }

  It 'creates HelloWorld folder and expected files with expected content' {
    $helloWorldFolder = Join-Path $GeneratedRoot 'HelloWorld'
    $programFile = Join-Path $helloWorldFolder 'Program.cs'
    $classFile = Join-Path $helloWorldFolder 'HelloWorld.cs'
    $projectFile = Join-Path $helloWorldFolder 'HelloWorld.csproj'

    Test-Path $helloWorldFolder | Should -BeTrue
    Test-Path $programFile | Should -BeTrue
    Test-Path $classFile | Should -BeTrue
    Test-Path $projectFile | Should -BeTrue

    (Get-Content -Path $programFile -Raw).TrimEnd() | Should -Be $ExpectedProgram
    (Get-Content -Path $classFile -Raw).TrimEnd() | Should -Be $ExpectedClass
    (Get-Content -Path $projectFile -Raw).TrimEnd() | Should -Be $ExpectedCsproj
  }

  AfterAll {
    $cleanupSql = @"
DECLARE @CSharpProgramRule UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111101';
DECLARE @CSharpClassRule UNIQUEIDENTIFIER   = '11111111-1111-1111-1111-111111111102';
DECLARE @MSBuildRule UNIQUEIDENTIFIER       = '11111111-1111-1111-1111-111111111103';
DECLARE @PathRule UNIQUEIDENTIFIER          = '11111111-1111-1111-1111-111111111104';

DECLARE @CSharpProgramInst UNIQUEIDENTIFIER = '22222222-2222-2222-2222-222222222201';
DECLARE @CSharpClassInst UNIQUEIDENTIFIER   = '22222222-2222-2222-2222-222222222202';
DECLARE @MSBuildInst UNIQUEIDENTIFIER       = '22222222-2222-2222-2222-222222222203';
DECLARE @PathInst UNIQUEIDENTIFIER          = '22222222-2222-2222-2222-222222222204';

DELETE FROM ATAPUtilities.RuleInstantiationBinding
WHERE InstantiationPhiloteId IN (@CSharpProgramInst, @CSharpClassInst, @MSBuildInst, @PathInst);

DELETE FROM ATAPUtilities.RuleInstantiation
WHERE PhiloteId IN (@CSharpProgramInst, @CSharpClassInst, @MSBuildInst, @PathInst);

DELETE FROM ATAPUtilities.[Rule]
WHERE PhiloteId IN (@CSharpProgramRule, @CSharpClassRule, @MSBuildRule, @PathRule);

DELETE FROM ATAPUtilities.Philote
WHERE PhiloteId IN (
  @CSharpProgramRule, @CSharpClassRule, @MSBuildRule, @PathRule,
  @CSharpProgramInst, @CSharpClassInst, @MSBuildInst, @PathInst
);
"@

    Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $cleanupSql | Out-Null
  }
}
