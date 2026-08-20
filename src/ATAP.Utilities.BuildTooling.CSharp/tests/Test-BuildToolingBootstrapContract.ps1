function Test-BuildToolingBootstrapContract {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  begin {
    $fn = 'Test-BuildToolingBootstrapContract'
    $mn = 'ATAP.Utilities.BuildTooling.CSharp.BootstrapTests'
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $repoRoot = (Resolve-Path (Join-Path $projectRoot '..\..')).Path
    $evidenceRoot = Join-Path $repoRoot '_generated\Sprint0015\Task15.180\d\bootstrap'
  }

  process {
    if (-not $PSCmdlet.ShouldProcess($projectRoot, 'Run offline BuildTooling package/bootstrap contract')) { return }
    try {
      function Invoke-ProcessChecked {
        param([string] $FilePath, [string[]] $ArgumentList, [string] $WorkingDirectory, [int[]] $ExpectedExitCodes = @(0))
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $FilePath
        $start.WorkingDirectory = $WorkingDirectory
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        foreach ($argument in $ArgumentList) { $start.ArgumentList.Add($argument) }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $start
        if (-not $process.Start()) { throw "Could not start $FilePath." }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $result = [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr; Text = $stdout + $stderr }
        if ($process.ExitCode -notin $ExpectedExitCodes) { throw "Unexpected exit $($process.ExitCode): $FilePath $($ArgumentList -join ' ')`n$($result.Text)" }
        $result
      }

      function Write-Utf8File { param([string] $Path, [string] $Content) [IO.File]::WriteAllText($Path, $Content.TrimStart("`r", "`n") + [Environment]::NewLine, [Text.UTF8Encoding]::new($false)) }
      function Get-PropertyValue {
        param([string] $Project, [string] $Name, [string] $WorkingDirectory)
        $result = Invoke-ProcessChecked 'dotnet' @('msbuild', $Project, "-getProperty:$Name") $WorkingDirectory
        ($result.StdOut.Trim() -split "`r?`n")[-1].Trim()
      }

      [IO.Directory]::CreateDirectory($evidenceRoot) | Out-Null
      $runRoot = Join-Path $evidenceRoot ([guid]::NewGuid().ToString('N'))
      $feedRoot = Join-Path $runRoot 'feed'
      $packagesRoot = Join-Path $runRoot 'packages'
      $consumerRoot = Join-Path $runRoot 'consumers'
      foreach ($path in @($runRoot, $feedRoot, $packagesRoot, $consumerRoot)) { [IO.Directory]::CreateDirectory($path) | Out-Null }

      $pack = Invoke-ProcessChecked 'dotnet' @('pack', (Join-Path $projectRoot 'ATAP.Utilities.BuildTooling.CSharp.csproj'), '--no-build', '--no-restore', '-c', 'Debug', '-p:SkipToolchainBaselineValidation=true', '-o', $feedRoot) $repoRoot
      if ($pack.Text -match 'NU5128') { throw 'Package emitted NU5128.' }
      $packages = @(Get-ChildItem -LiteralPath $feedRoot -Filter '*.nupkg')
      if ($packages.Count -ne 1) { throw "Expected one package; found $($packages.Count)." }
      $package = $packages[0]
      $prefix = 'ATAP.Utilities.BuildTooling.CSharp.'
      $version = $package.BaseName.Substring($prefix.Length)

      Add-Type -AssemblyName System.IO.Compression.FileSystem
      $archive = [IO.Compression.ZipFile]::OpenRead($package.FullName)
      try {
        $entries = @($archive.Entries | ForEach-Object { $_.FullName })
        $expectedEntries = @(
          'build/ATAP.Utilities.BuildTooling.CSharp.targets',
          'buildTransitive/ATAP.Utilities.BuildTooling.CSharp.targets',
          'tools/net8.0/ATAP.Utilities.BuildTooling.CSharp.dll',
          'tools/net9.0/ATAP.Utilities.BuildTooling.CSharp.dll',
          'tools/net10.0/ATAP.Utilities.BuildTooling.CSharp.dll',
          'ReadMe.md'
        )
        foreach ($entry in $expectedEntries) { if ($entry -notin $entries) { throw "Missing package entry $entry" } }
        $nuspecEntry = $archive.Entries | Where-Object { $_.FullName -like '*.nuspec' } | Select-Object -First 1
        $reader = [IO.StreamReader]::new($nuspecEntry.Open())
        try { [xml] $nuspec = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $metadata = $nuspec.package.metadata
        if ([string] $metadata.id -ne 'ATAP.Utilities.BuildTooling.CSharp' -or [string] $metadata.version -ne $version) { throw 'Nuspec identity/version mismatch.' }
        if ($null -eq $metadata.repository -or [string] $metadata.repository.type -ne 'git' -or [string]::IsNullOrWhiteSpace([string] $metadata.repository.commit)) { throw 'Nuspec Git provenance is incomplete.' }
      } finally { $archive.Dispose() }

      $extractRoot = Join-Path $runRoot 'extracted'
      [IO.Compression.ZipFile]::ExtractToDirectory($package.FullName, $extractRoot)
      $directTargets = Join-Path $extractRoot 'build\ATAP.Utilities.BuildTooling.CSharp.targets'
      $transitiveTargets = Join-Path $extractRoot 'buildTransitive\ATAP.Utilities.BuildTooling.CSharp.targets'
      $directHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $directTargets).Hash
      $transitiveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $transitiveTargets).Hash
      if ($directHash -ne $transitiveHash) { throw 'Direct and transitive target bytes differ.' }

      Write-Utf8File (Join-Path $consumerRoot 'Directory.Build.props') '<Project><PropertyGroup><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup></Project>'
      Write-Utf8File (Join-Path $consumerRoot 'Directory.Build.targets') '<Project />'
      Write-Utf8File (Join-Path $consumerRoot 'Directory.Packages.props') '<Project><PropertyGroup><ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally></PropertyGroup></Project>'
      $escapedFeed = [Security.SecurityElement]::Escape($feedRoot)
      $escapedPackages = [Security.SecurityElement]::Escape($packagesRoot)
      $configPath = Join-Path $consumerRoot 'NuGet.Config'
      Write-Utf8File $configPath ('<configuration><packageSources><clear /><add key="local" value="{0}" /></packageSources></configuration>' -f $escapedFeed)
      $guard = '<Target Name="ATAPRequireBuildToolingImport" BeforeTargets="PrepareForBuild"><Error Condition="''$(ATAPBuildToolingImported)'' != ''true''" Code="ATAPBUILD009" Text="Required ATAP BuildTooling package import is missing." /></Target>'
      $directProject = Join-Path $consumerRoot 'Direct.csproj'
      $directXml = "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><TargetFramework>net10.0</TargetFramework><RestoreSources>$escapedFeed</RestoreSources><RestorePackagesPath>$escapedPackages</RestorePackagesPath></PropertyGroup><ItemGroup><PackageReference Include=`"ATAP.Utilities.BuildTooling.CSharp`" Version=`"$version`" /></ItemGroup>$guard</Project>"
      Write-Utf8File $directProject $directXml

      $providerDir = Join-Path $consumerRoot 'Provider'
      $leafDir = Join-Path $consumerRoot 'Leaf'
      [IO.Directory]::CreateDirectory($providerDir) | Out-Null
      [IO.Directory]::CreateDirectory($leafDir) | Out-Null
      $providerProject = Join-Path $providerDir 'Provider.csproj'
      $leafProject = Join-Path $leafDir 'Leaf.csproj'
      Write-Utf8File $providerProject "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><TargetFramework>net10.0</TargetFramework><RestoreSources>$escapedFeed</RestoreSources><RestorePackagesPath>$escapedPackages</RestorePackagesPath></PropertyGroup><ItemGroup><PackageReference Include=`"ATAP.Utilities.BuildTooling.CSharp`" Version=`"$version`" /></ItemGroup></Project>"
      Write-Utf8File $leafProject "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><TargetFramework>net10.0</TargetFramework><RestoreSources>$escapedFeed</RestoreSources><RestorePackagesPath>$escapedPackages</RestorePackagesPath></PropertyGroup><ItemGroup><ProjectReference Include=`"..\Provider\Provider.csproj`" /></ItemGroup>$guard</Project>"

      $restoreArgs = @('restore', $directProject, '--force', '--configfile', $configPath, '--packages', $packagesRoot)
      $null = Invoke-ProcessChecked 'dotnet' $restoreArgs $consumerRoot
      $null = Invoke-ProcessChecked 'dotnet' @('msbuild', $directProject, '-t:ATAPValidateBuildToolingCompatibility') $consumerRoot
      $null = Invoke-ProcessChecked 'dotnet' @('restore', $leafProject, '--force', '--configfile', $configPath, '--packages', $packagesRoot) $consumerRoot
      $null = Invoke-ProcessChecked 'dotnet' @('msbuild', $leafProject, '-t:ATAPValidateBuildToolingCompatibility') $consumerRoot

      $propertyNames = @('ATAPBuildToolingPackageId', 'ATAPBuildToolingContractVersion', 'ATAPBuildToolingCompatibilitySentinel')
      $directProperties = @{}
      $transitiveProperties = @{}
      foreach ($name in $propertyNames) {
        $directProperties[$name] = Get-PropertyValue $directProject $name $consumerRoot
        $transitiveProperties[$name] = Get-PropertyValue $leafProject $name $consumerRoot
        if ($directProperties[$name] -ne $transitiveProperties[$name]) { throw "Direct/transitive property mismatch: $name" }
      }

      $cachedTargets = Join-Path $packagesRoot "atap.utilities.buildtooling.csharp\$($version.ToLowerInvariant())\build\ATAP.Utilities.BuildTooling.CSharp.targets"
      $cachedTransitiveTargets = Join-Path $packagesRoot "atap.utilities.buildtooling.csharp\$($version.ToLowerInvariant())\buildTransitive\ATAP.Utilities.BuildTooling.CSharp.targets"
      $beforeRepeatHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $cachedTargets).Hash
      $lock = [IO.File]::Open($cachedTargets, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
      try { $null = Invoke-ProcessChecked 'dotnet' $restoreArgs $consumerRoot } finally { $lock.Dispose() }
      $afterRepeatHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $cachedTargets).Hash
      if ($beforeRepeatHash -ne $afterRepeatHash) { throw 'Repeated restore changed immutable target bytes.' }

      $versionMismatch = Invoke-ProcessChecked 'dotnet' @('msbuild', $directProject, '-t:ATAPValidateBuildToolingCompatibility', '-p:ATAPBuildToolingRequiredContractVersion=2') $consumerRoot @(1)
      if ($versionMismatch.Text -notmatch 'ATAPBUILD010') { throw 'Version mismatch did not fail with ATAPBUILD010.' }
      $sentinelMismatch = Invoke-ProcessChecked 'dotnet' @('msbuild', $directProject, '-t:ATAPValidateBuildToolingCompatibility', '-p:ATAPBuildToolingRequiredCompatibilitySentinel=corrupt') $consumerRoot @(1)
      if ($sentinelMismatch.Text -notmatch 'ATAPBUILD011') { throw 'Sentinel mismatch did not fail with ATAPBUILD011.' }
      $missingAssembly = Invoke-ProcessChecked 'dotnet' @('msbuild', $directProject, '-t:ATAPValidateBuildToolingCompatibility', '-p:ATAPBuildToolingRequireTaskAssembly=true', '-p:ATAPUtilitiesBuildToolingTasksAssembly=missing.dll') $consumerRoot @(1)
      if ($missingAssembly.Text -notmatch 'ATAPBUILD012') { throw 'Missing task assembly did not fail with ATAPBUILD012.' }

      $missingTargetBackup = "$cachedTargets.missing"
      $missingTransitiveBackup = "$cachedTransitiveTargets.missing"
      [IO.File]::Move($cachedTargets, $missingTargetBackup)
      [IO.File]::Move($cachedTransitiveTargets, $missingTransitiveBackup)
      try {
        $missingTarget = Invoke-ProcessChecked 'dotnet' @('msbuild', $directProject, '-t:ATAPRequireBuildToolingImport') $consumerRoot @(1)
        if ($missingTarget.Text -notmatch 'ATAPBUILD009') { throw 'Missing package targets did not fail with the consumer bootstrap diagnostic ATAPBUILD009.' }
      } finally {
        [IO.File]::Move($missingTargetBackup, $cachedTargets)
        [IO.File]::Move($missingTransitiveBackup, $cachedTransitiveTargets)
      }

      $missingVersionXml = $directXml.Replace("Version=`"$version`"", 'Version="99.99.99-missing"')
      Write-Utf8File $directProject $missingVersionXml
      $missingVersion = Invoke-ProcessChecked 'dotnet' @('restore', $directProject, '--force', '--no-cache', '--configfile', $configPath, '--packages', $packagesRoot) $consumerRoot @(1)
      if ($missingVersion.Text -notmatch 'NU1102') { throw 'Unavailable exact version did not fail closed with NU1102.' }
      Write-Utf8File $directProject $directXml
      $null = Invoke-ProcessChecked 'dotnet' $restoreArgs $consumerRoot
      $null = Invoke-ProcessChecked 'dotnet' @('msbuild', $directProject, '-t:ATAPValidateBuildToolingCompatibility') $consumerRoot

      $result = [ordered]@{
        result = 'Passed'; package = $package.Name; version = $version; packageSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $package.FullName).Hash
        requiredEntries = 6; directTransitiveTargetsSha256 = $directHash; directTransitiveProperties = $directProperties
        firstUseRestore = 'Passed'; transitiveConsumer = 'Passed'; repeatedRestoreUnderFileLock = 'Passed'; rollbackToKnownGood = 'Passed'
        diagnostics = @('ATAPBUILD009', 'ATAPBUILD010', 'ATAPBUILD011', 'ATAPBUILD012'); feedContact = 'local-only'; publication = $false; signingKeyAccess = $false
        runRoot = $runRoot
      }
      $evidencePath = Join-Path $evidenceRoot 'verification.json'
      Write-Utf8File $evidencePath ($result | ConvertTo-Json -Depth 6)
      [pscustomobject] $result
    } catch {
      if (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message }
      throw
    }
  }

  end {}
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  Test-BuildToolingBootstrapContract -Confirm:$false
}
