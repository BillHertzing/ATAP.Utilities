<#
.SYNOPSIS
Installs an exact ATAP module version to the AllUsers scope from a ProGet feed, with hash and
dependency validation, when Install-Module cannot.

.DESCRIPTION
The canonical validated AllUsers installer. It exists because
`Install-Module -Repository powershellget-stable -Scope AllUsers` resolves dependencies only against
that feed, and the ATAP stable feed does not carry external dependencies such as PSFramework. That
makes Install-Module fail with "Unable to find dependent module(s)" for a package that is otherwise
perfectly installable (Sprint 0013 Task 13.76.e). Agents must not improvise `-SkipDependencies`;
they call this instead.

The install is deliberately strict and all-or-nothing:

  1. Requires elevation, and exits with status 2 (not a crash) when absent.
  2. Resolves a reachable download endpoint, preferring the direct package form -- ProGet Free
     answers the OData v2 form with "OData method is not implemented".
  3. Verifies the downloaded package against -ExpectedSha256 before anything is written under
     Program Files, so a substituted or corrupted artifact cannot be installed.
  4. Verifies every signable PowerShell file has a valid timestamped Authenticode signature.
  5. Validates every declared dependency against the INSTALLED floor read from the package's own
     manifest, rather than asking the feed to resolve it.
  6. Refuses to overwrite an existing version folder, because ProGet versions are immutable and
     silently replacing one hides which bits are actually deployed.
  7. Stages in a temp folder, then creates the version folder under the AllUsers modules root and
     copies the staged contents into it. Creating the target in place is intentional: a move from
     the broker service account's temporary directory preserves that account's restrictive ACL,
     making the apparent AllUsers install unreadable to normal consumers.
  8. Rolls back a version folder THIS run created if any validation fails, so a retry reports the
     real error instead of "Version folder already exists".

Every run writes a transcript and a JSON result record under `_generated\deploy\` (SC-0033).

.PARAMETER ModuleName
Module/package id to install.

.PARAMETER RequiredVersion
Exact version to install. No ranges: the value becomes the immutable version folder name.

.PARAMETER Repository
Registered PSRepository name for the feed. A temporary repository is registered and removed if the
name is not already registered.

.PARAMETER FeedUrl
Feed base URL used to build the package download endpoint.

.PARAMETER ExpectedSha256
SHA-256 pin for the .nupkg. Required: an unpinned install is not a validated install.

.PARAMETER ModulesRoot
AllUsers modules root. Defaults to the PowerShell 7 AllUsers root; overridable for testing.

.PARAMETER DeployRoot
Folder for the transcript and JSON result record. Defaults to `_generated\deploy` under the
repository root.

.OUTPUTS
System.Management.Automation.PSCustomObject with ModuleName, RequiredVersion, Repository, FeedUrl,
StartTime, EndTime, ExitStatus (0 ok, 1 failure, 2 not elevated), ActualSha256, DownloadUri,
DependencyFailures, VersionPath, RolledBack, TranscriptPath, ResultJsonPath, ErrorText.

.EXAMPLE
Install-ATAPModuleAllUsers -ModuleName 'ATAP.Utilities.BuildTooling.Common.PowerShell' `
  -RequiredVersion '0.1.8' -Repository 'powershellget-stable' `
  -FeedUrl 'https://localhost:50000/nuget/powershellget-stable' `
  -ExpectedSha256 '6795AD76AC3DD5CC35AAA2CDCEFC734B8043F498A8C9F2103F19EC8169BD9F7F'

.NOTES
Task 13.76.c promoted this from the standalone `_Planning` CodexMisstepFixes script into this child
module. The parent's frozen compatibility surface is intentionally NOT extended with it.
AI assisted using Powershell.instructions.md as guidelines.
#>
function Install-ATAPModuleAllUsers {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$RequiredVersion,

    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [string]$Repository,

    [Parameter(Mandatory = $true, Position = 3)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
      $uri = [uri]$_
      if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https') {
        throw 'FeedUrl must be an absolute HTTPS URI. Cleartext module installation is not allowed.'
      }
      $true
    })]
    [string]$FeedUrl,

    [Parameter(Mandatory = $true, Position = 4)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedSha256,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ModulesRoot = 'C:\Program Files\PowerShell\Modules',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DeployRoot
  )

  begin {
    $fn = 'Install-ATAPModuleAllUsers'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not $PSBoundParameters.ContainsKey('DeployRoot') -or [string]::IsNullOrWhiteSpace($DeployRoot)) {
      $repoRoot = if (Get-Command -Name 'Get-RepositoryRoot' -ErrorAction SilentlyContinue) {
        try { Get-RepositoryRoot } catch { $null }
      }
      else { $null }
      if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
      # SC-0033: generated output belongs under _generated at the repository root.
      $DeployRoot = Join-Path -Path $repoRoot -ChildPath '_generated\deploy'
    }
  }

  process {
    $result = [PSCustomObject]@{
      ModuleName         = $ModuleName
      RequiredVersion    = $RequiredVersion
      Repository         = $Repository
      FeedUrl            = $FeedUrl
      StartTime          = (Get-Date)
      EndTime            = $null
      ExitStatus         = 0
      ActualSha256       = $null
      SignatureVerified = $false
      DownloadUri        = $null
      DependencyFailures = @()
      VersionPath        = $null
      RolledBack         = $false
      TranscriptPath     = $null
      ResultJsonPath     = $null
      TempRepositoryName = $null
      ErrorText          = ''
    }

    $tempPaths = [System.Collections.Generic.List[string]]::new()
    $transcriptStarted = $false
    $createdVersionPath = $null

    if (-not (Test-Path -LiteralPath $DeployRoot)) {
      New-Item -ItemType Directory -Path $DeployRoot -Force | Out-Null
    }
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $result.TranscriptPath = Join-Path -Path $DeployRoot -ChildPath "Install-ATAPModuleAllUsers-$ModuleName-$RequiredVersion-$ts.log"
    try {
      Start-Transcript -Path $result.TranscriptPath -Force | Out-Null
      $transcriptStarted = $true
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Could not start transcript: $($_.Exception.Message)"
    }

    try {
      if (-not (Test-ATAPModuleAllUsersElevated)) {
        $result.ExitStatus = 2
        throw "Install-ATAPModuleAllUsers requires Administrator rights. Re-run from an elevated shell, or route the request through the ATAP elevation broker."
      }

      if (-not (Get-PSRepository -Name $Repository -ErrorAction SilentlyContinue)) {
        $tempName = "ATAP-Temp-Feed-Install-$([guid]::NewGuid().Guid.Replace('-', ''))"
        Register-PSRepository -Name $tempName -SourceLocation $FeedUrl -InstallationPolicy Trusted -ErrorAction Stop
        $result.TempRepositoryName = $tempName
      }

      $result.DownloadUri = Get-ATAPModuleDownloadUri -FeedUrl $FeedUrl -ModuleName $ModuleName -RequiredVersion $RequiredVersion

      $tempRoot = Join-Path -Path $env:TEMP -ChildPath "ATAP-InstallModule-$([guid]::NewGuid().Guid.Replace('-', ''))"
      New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
      $tempPaths.Add($tempRoot)

      $nupkgPath = Join-Path -Path $tempRoot -ChildPath "$ModuleName.$RequiredVersion.nupkg"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $($result.DownloadUri)" -Tag 'WebRequestCall'
      Invoke-WebRequest -Uri $result.DownloadUri -OutFile $nupkgPath -UseBasicParsing -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $($result.DownloadUri)" -Tag 'WebRequestCall'

      $result.ActualSha256 = (Get-FileHash -Algorithm SHA256 -Path $nupkgPath).Hash
      if (-not (Test-ATAPModuleFileHash -Path $nupkgPath -ExpectedSha256 $ExpectedSha256)) {
        $result.ExitStatus = 1
        throw "SHA-256 validation failed for $nupkgPath. Expected $ExpectedSha256, actual $($result.ActualSha256)."
      }

      $signatureEvidencePath = Join-Path -Path $DeployRoot -ChildPath 'signature-verification'
      Test-PSModulePackageSignature -NupkgPath $nupkgPath `
        -ResultsPath $signatureEvidencePath -RequireTimestamp -ErrorAction Stop | Out-Null
      $result.SignatureVerified = $true

      $extractPath = Join-Path -Path $tempRoot -ChildPath 'expand'
      Expand-Archive -Path $nupkgPath -DestinationPath $extractPath -Force

      $moduleManifest = Get-ChildItem -Path $extractPath -Recurse -Filter '*.psd1' -File |
        Where-Object { $_.Name -like "$ModuleName*.psd1" } |
        Select-Object -First 1
      if (-not $moduleManifest) {
        $result.ExitStatus = 1
        throw "Could not locate a module manifest in downloaded package $nupkgPath."
      }

      # @() is required on both calls: an empty array returned from a process block is
      # unwrapped to $null by the pipeline, and a null would fail parameter binding on a
      # package that simply declares no dependencies.
      $dependencyRequirements = @(Get-ATAPModuleDependencyRequirementsFromManifest -ModuleManifestPath $moduleManifest.FullName)
      $installedModules = Get-ATAPModuleInstalledVersions
      $result.DependencyFailures = @(Get-ATAPModuleDependencyFloorViolations -DependencyRequirements $dependencyRequirements -InstalledModules $installedModules)
      if ($result.DependencyFailures.Count -gt 0) {
        $result.ExitStatus = 1
        $detail = ($result.DependencyFailures | ForEach-Object { "$($_.Dependency) requires >= $($_.RequiredMinimum), installed '$($_.Installed)' ($($_.Status))" }) -join '; '
        throw "Installed module dependencies do not satisfy floor requirements: $detail"
      }

      $versionTargetPath = Get-ATAPModuleVersionInstallPath -ModuleName $ModuleName -RequiredVersion $RequiredVersion -ModulesRoot $ModulesRoot
      if (Test-Path -LiteralPath $versionTargetPath) {
        $result.ExitStatus = 1
        throw "Version folder already exists and was not overwritten: $versionTargetPath"
      }

      if ($PSCmdlet.ShouldProcess($versionTargetPath, "Install $ModuleName v$RequiredVersion")) {
        $stagingFolder = Join-Path -Path $tempRoot -ChildPath "staging\$ModuleName\$RequiredVersion"
        New-Item -ItemType Directory -Path $stagingFolder -Force | Out-Null

        # Copy the CONTENTS of the manifest's folder, not the folder itself: passing the directory
        # to -LiteralPath nests it as <Version>\expand\<Name>.psd1 and the staging check below then
        # fails on a package that is perfectly good.
        $packageContentRoot = Split-Path -Path $moduleManifest.FullName -Parent
        Copy-Item -Path (Join-Path -Path $packageContentRoot -ChildPath '*') -Destination $stagingFolder -Recurse -Force

        # Do not Move-Item the staging directory into Program Files. A moved directory retains the
        # broker account's ACL from its private temp root. Create the version folder under the
        # AllUsers module root so it inherits that root's consumer-readable ACL, then copy contents.
        New-Item -ItemType Directory -Path $versionTargetPath -Force | Out-Null
        Copy-Item -Path (Join-Path -Path $stagingFolder -ChildPath '*') -Destination $versionTargetPath -Recurse -Force
        $result.VersionPath = $versionTargetPath
        $createdVersionPath = $versionTargetPath
      }
      else {
        $result.ExitStatus = 1
        throw 'Operation was cancelled by -WhatIf.'
      }

      $stagedManifest = Join-Path -Path $versionTargetPath -ChildPath $moduleManifest.Name
      if (-not (Test-Path -LiteralPath $stagedManifest)) {
        $result.ExitStatus = 1
        throw "Installed module manifest was not found after staging: $stagedManifest"
      }

      Remove-Module -Name $ModuleName -ErrorAction SilentlyContinue
      Import-Module -FullyQualifiedName $stagedManifest -Force -ErrorAction Stop

      # Match on ModuleBase, not Path: PowerShell sets Path to the .psm1 when a manifest declares a
      # RootModule, so comparing Path to the .psd1 never matches even on a good install.
      $imported = Get-Module -Name $ModuleName -ErrorAction SilentlyContinue |
        Where-Object {
          $_.ModuleBase -and
          ([IO.Path]::GetFullPath($_.ModuleBase).TrimEnd('\') -ieq [IO.Path]::GetFullPath($versionTargetPath).TrimEnd('\'))
        } |
        Select-Object -First 1
      if (-not $imported) {
        $result.ExitStatus = 1
        $loadedFrom = (Get-Module -Name $ModuleName -ErrorAction SilentlyContinue | ForEach-Object { $_.ModuleBase }) -join '; '
        throw "Fresh-import validation failed for $stagedManifest. Expected a module loaded from '$versionTargetPath'; loaded module base(s): '$loadedFrom'."
      }

      if ($imported.Version -ne [version]$RequiredVersion) {
        $result.ExitStatus = 1
        throw "Installed module version '$($imported.Version)' does not match requested version '$RequiredVersion'."
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Installed $ModuleName $RequiredVersion to $versionTargetPath (SHA-256 $($result.ActualSha256))."
    }
    catch {
      $result.ExitStatus = if ($result.ExitStatus -gt 0) { $result.ExitStatus } else { 1 }
      $result.ErrorText = $_.Exception.Message

      # Roll back only what THIS run created; a pre-existing install is never touched.
      if ($createdVersionPath -and (Test-Path -LiteralPath $createdVersionPath)) {
        try {
          Remove-Item -LiteralPath $createdVersionPath -Recurse -Force -ErrorAction Stop
          $result.VersionPath = $null
          $result.RolledBack = $true
        }
        catch {
          $result.ErrorText += " Additionally, rollback of '$createdVersionPath' failed: $($_.Exception.Message). Remove it manually before retrying."
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $result.ErrorText
    }
    finally {
      $result.EndTime = Get-Date
      $result.ResultJsonPath = Join-Path -Path $DeployRoot -ChildPath "Install-ATAPModuleAllUsers-$ModuleName-$RequiredVersion-$ts.json"
      try {
        $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $result.ResultJsonPath -Encoding UTF8
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Could not write result record: $($_.Exception.Message)"
      }

      if ($result.TempRepositoryName) {
        Unregister-PSRepository -Name $result.TempRepositoryName -ErrorAction SilentlyContinue
      }
      foreach ($path in $tempPaths) {
        if (Test-Path -LiteralPath $path) {
          Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
      }
      if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch { }
      }
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
