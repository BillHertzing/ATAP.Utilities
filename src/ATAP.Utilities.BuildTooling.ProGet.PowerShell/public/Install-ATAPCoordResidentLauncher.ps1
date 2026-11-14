<#
.SYNOPSIS
Installs the Orchestration resident's version-independent stable launcher to its fixed Program Files path.

.DESCRIPTION
Broker entry `install-coord-resident-launcher` (Orchestration 0.1.17 design, slice 7, route (a)).

Copies exactly one file:

  C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.Orchestration.PowerShell\<ModuleVersion>\Resources\Resident\Start-CoordClerkResident.ps1
  ->  C:\Program Files\ATAP\Orchestration\Start-CoordClerkResident.ps1

The caller supplies only ModuleVersion and ExpectedSha256. The source root, module name, destination
and receipt folder are fixed here and are never request-settable, the same way Install-ATAPModuleAllUsers
withholds ModulesRoot and DeployRoot from the broker allowlist.

Before writing, it requires:

  1. elevation;
  2. exactly one AllUsers install of that module version, whose manifest declares that version;
  3. the bundled launcher hashing to ExpectedSha256;
  4. a Valid Authenticode signature from the policy signer 3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E;
  5. no reparse point on any existing ancestor of the source or the destination;
  6. custody (the Orchestration custody record named by the OrchestrationCustodyRecordPath setting)
     currently admitting exactly this ModuleVersion, with its inventory pinning the bundled launcher
     at ExpectedSha256 (review M1: never install a launcher custody has not admitted);
  7. no downgrade: when a launcher is already installed, the version it came from (the protected
     source record beside it, or else the highest installed version whose bundled launcher has the
     same bytes) must not be higher than ModuleVersion. An installed launcher whose source cannot be
     established is refused rather than guessed.

Ordering (slice 10 and every later release that changes the launcher): custody must admit the new
version first, then this entry installs its launcher, then the resident restarts. Installing before
admission is refused by check 6; a resident restarted before the install refuses itself
(LauncherSelfNotAdmitted). Test-CoordLauncherUpgradeCompatibility in Start-CoordClerkResident.ps1 lets
the upgrade orchestrator detect a launcher change before it writes anything.

The write is atomic: a temp file in the destination folder, a hash re-check, the protected ACL applied,
then File.Replace (or File.Move when no copy exists yet), and the ACL applied again and verified.
The protected ACL has owner Administrators; Administrators and SYSTEM have FullControl; Users have
ReadAndExecute; inheritance is disabled.

Every run, successful or refused, writes a JSON receipt with the before and after hashes under
`_generated\deploy` (SC-0033). An existing copy is preserved there as a hash-named preimage before it
is replaced.

Refusals throw one distinct code:
  CoordLauncherNotElevated, CoordLauncherModuleNotInstalled, CoordLauncherInstallAmbiguous,
  CoordLauncherSourceHashMismatch, CoordLauncherSignatureInvalid, CoordLauncherSignerMismatch,
  CoordLauncherReparsePathRefused, CoordLauncherCopyVerificationFailed, CoordLauncherAclVerificationFailed,
  CoordLauncherCustodyUnavailable, CoordLauncherVersionNotAdmitted, CoordLauncherDigestNotAdmitted,
  CoordLauncherInstalledSourceUnknown, CoordLauncherDowngradeRefused.

After a successful install the protected source record Start-CoordClerkResident.ps1.source.json
(ModuleVersion, Sha256) is written beside the launcher with the same ACL; check 7 reads it.

.PARAMETER ModuleVersion
Exact installed Orchestration module version whose bundled launcher is copied (for example 0.1.17).

.PARAMETER ExpectedSha256
SHA-256 of the bundled launcher that the caller has approved, typically the custody-admitted inventory
digest of Resources/Resident/Start-CoordClerkResident.ps1.

.OUTPUTS
PSCustomObject with ExitStatus (0 on success, the broker module-command contract), ModuleVersion,
SourcePath, DestinationPath, BeforeSha256, AfterSha256, SignerThumbprint, PreimagePath, ReceiptPath.

.EXAMPLE
Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 '34FAF9B9...'

.NOTES
Enabling this entry on a host requires the operator-gated edit of C:\ProgramData\ATAP\ElevationBroker\config.json.
AI assisted using Powershell.instructions.md as guidelines.

.LINK
../Documentation/ElevationBroker.md
#>
function Install-ATAPCoordResidentLauncher {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('\A\d+\.\d+\.\d+\z')]
    [string]$ModuleVersion,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('\A[0-9A-Fa-f]{64}\z')]
    [string]$ExpectedSha256
  )

  begin {
    $fn = 'Install-ATAPCoordResidentLauncher'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    $layout = Get-ATAPCoordResidentLauncherLayout
  }

  process {
    $result = [PSCustomObject]@{
      ExitStatus       = 1
      ErrorCode        = $null
      ModuleVersion    = $ModuleVersion
      SourcePath       = $null
      DestinationPath  = $layout.DestinationPath
      ExpectedSha256   = $ExpectedSha256.ToUpperInvariant()
      BeforeSha256     = $null
      AfterSha256      = $null
      SignerThumbprint = $null
      InstalledFromVersion = $null
      SourceRecordPath = $null
      PreimagePath     = $null
      ReceiptPath      = $null
      StartTime        = (Get-Date).ToUniversalTime().ToString('o')
      EndTime          = $null
    }
    $temp = $null
    try {
      if (-not (Test-ATAPModuleAllUsersElevated)) { throw 'CoordLauncherNotElevated' }

      # Resolve the single AllUsers install of the named version. No caller-supplied path.
      $moduleBase = Join-Path $layout.ModulesRoot $layout.ModuleName
      $versionDir = Join-Path $moduleBase $ModuleVersion
      if (-not (Test-Path -LiteralPath $versionDir -PathType Container)) { throw 'CoordLauncherModuleNotInstalled' }
      # Folders that denote the same version (for example 0.1.17 and 0.1.17.0) make the install ambiguous.
      $wanted = [version]$ModuleVersion
      $sameVersion = @(Get-ChildItem -LiteralPath $moduleBase -Directory | Where-Object {
          $v = $null
          [version]::TryParse($_.Name, [ref]$v) -and $v.Major -eq $wanted.Major -and $v.Minor -eq $wanted.Minor -and
            [Math]::Max($v.Build, 0) -eq [Math]::Max($wanted.Build, 0) -and [Math]::Max($v.Revision, 0) -eq 0 })
      $manifests = @(Get-ChildItem -LiteralPath $versionDir -Filter '*.psd1' -File)
      if ($sameVersion.Count -ne 1 -or $manifests.Count -ne 1 -or $manifests[0].Name -cne ($layout.ModuleName + '.psd1')) { throw 'CoordLauncherInstallAmbiguous' }
      $declared = (Import-PowerShellDataFile -LiteralPath $manifests[0].FullName).ModuleVersion
      if ([string]$declared -cne $ModuleVersion) { throw 'CoordLauncherInstallAmbiguous' }
      $source = Join-Path $versionDir $layout.RelativeLauncherPath
      if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'CoordLauncherModuleNotInstalled' }
      $result.SourcePath = $source

      foreach ($path in @($source, $layout.DestinationPath)) {
        for ($part = [IO.Path]::GetFullPath($path); $part; $part = [IO.Path]::GetDirectoryName($part)) {
          if (Test-Path -LiteralPath $part) {
            if ((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'CoordLauncherReparsePathRefused' }
          }
        }
      }

      $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
      if (-not [string]::Equals($sourceHash, $ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)) { throw 'CoordLauncherSourceHashMismatch' }
      $signature = Get-AuthenticodeSignature -LiteralPath $source
      if ($signature.Status -ne 'Valid') { throw 'CoordLauncherSignatureInvalid' }
      $result.SignerThumbprint = $signature.SignerCertificate.Thumbprint
      if (-not [string]::Equals($signature.SignerCertificate.Thumbprint, $layout.SignerThumbprint, [StringComparison]::OrdinalIgnoreCase)) { throw 'CoordLauncherSignerMismatch' }

      # Custody must admit this exact version and launcher digest (review M1).
      $admitted = Get-ATAPCoordLauncherCustodyPin -CustodyPath $layout.CustodyPath
      if ($admitted.ModuleVersion -cne $ModuleVersion) { throw 'CoordLauncherVersionNotAdmitted' }
      if (-not [string]::Equals($admitted.LauncherSha256, $ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)) { throw 'CoordLauncherDigestNotAdmitted' }

      $destDir = [IO.Path]::GetDirectoryName($layout.DestinationPath)
      if (Test-Path -LiteralPath $layout.DestinationPath -PathType Leaf) {
        $result.BeforeSha256 = (Get-FileHash -LiteralPath $layout.DestinationPath -Algorithm SHA256).Hash
        # No downgrade, and no guessing about what is installed.
        $installedFrom = Get-ATAPCoordLauncherInstalledSource -Layout $layout -InstalledSha256 $result.BeforeSha256
        if (-not $installedFrom) { throw 'CoordLauncherInstalledSourceUnknown' }
        $result.InstalledFromVersion = $installedFrom
        if ([version]$installedFrom -gt [version]$ModuleVersion) { throw 'CoordLauncherDowngradeRefused' }
      }

      if (-not $PSCmdlet.ShouldProcess($layout.DestinationPath, "Install stable launcher from Orchestration $ModuleVersion")) {
        $result.ExitStatus = 0; $result.ErrorCode = 'WhatIfNoWrite'
        return $result
      }

      if (-not (Test-Path -LiteralPath $destDir -PathType Container)) { $null = New-Item -ItemType Directory -Path $destDir -Force }
      if (-not (Test-Path -LiteralPath $layout.DeployRoot -PathType Container)) { $null = New-Item -ItemType Directory -Path $layout.DeployRoot -Force }
      if ($result.BeforeSha256) {
        $result.PreimagePath = Join-Path $layout.DeployRoot ("Start-CoordClerkResident.preimage-{0}.ps1" -f $result.BeforeSha256)
        if (-not (Test-Path -LiteralPath $result.PreimagePath)) { Copy-Item -LiteralPath $layout.DestinationPath -Destination $result.PreimagePath }
      }

      # Atomic write: same-folder temp file, re-check, protect, then replace or move.
      $temp = Join-Path $destDir ("Start-CoordClerkResident.ps1.tmp-{0}" -f [guid]::NewGuid().ToString('N'))
      Copy-Item -LiteralPath $source -Destination $temp
      if (-not [string]::Equals((Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash, $sourceHash, [StringComparison]::OrdinalIgnoreCase)) { throw 'CoordLauncherCopyVerificationFailed' }
      $acl = New-ATAPCoordLauncherProtectedAcl
      Set-Acl -LiteralPath $temp -AclObject $acl
      # [NullString]::Value, not $null: PowerShell converts $null to '' for a string argument, and
      # File.Replace then rejects the empty backup path. The preimage is already preserved above.
      if ($result.BeforeSha256) { [IO.File]::Replace($temp, $layout.DestinationPath, [NullString]::Value) } else { [IO.File]::Move($temp, $layout.DestinationPath) }
      $temp = $null
      Set-Acl -LiteralPath $layout.DestinationPath -AclObject $acl

      $applied = Get-Acl -LiteralPath $layout.DestinationPath
      if (-not $applied -or -not $applied.AreAccessRulesProtected -or $applied.GetSecurityDescriptorSddlForm('Owner,Access') -cne $acl.GetSecurityDescriptorSddlForm('Owner,Access')) { throw 'CoordLauncherAclVerificationFailed' }
      $result.AfterSha256 = (Get-FileHash -LiteralPath $layout.DestinationPath -Algorithm SHA256).Hash
      if (-not [string]::Equals($result.AfterSha256, $sourceHash, [StringComparison]::OrdinalIgnoreCase)) { throw 'CoordLauncherCopyVerificationFailed' }

      # Protected source record for the next run's downgrade check (same atomic pattern and ACL).
      $recordJson = [ordered]@{ ModuleVersion = $ModuleVersion; Sha256 = $result.AfterSha256; InstalledUtc = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json
      $recordTemp = Join-Path $destDir ("Start-CoordClerkResident.ps1.source.json.tmp-{0}" -f [guid]::NewGuid().ToString('N'))
      [IO.File]::WriteAllText($recordTemp, $recordJson, [Text.UTF8Encoding]::new($false))
      Set-Acl -LiteralPath $recordTemp -AclObject $acl
      [IO.File]::Move($recordTemp, $layout.SourceRecordPath, $true)
      Set-Acl -LiteralPath $layout.SourceRecordPath -AclObject $acl
      $result.SourceRecordPath = $layout.SourceRecordPath

      $result.ExitStatus = 0
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Stable launcher installed from Orchestration $ModuleVersion; before $($result.BeforeSha256), after $($result.AfterSha256)."
    }
    catch {
      $code = $_.Exception.Message
      $result.ErrorCode = if ($code -cmatch '\ACoordLauncher[A-Za-z]+\z') { $code } else { 'CoordLauncherUnexpectedFailure' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stable launcher install refused: $($result.ErrorCode)"
      if ($temp -and (Test-Path -LiteralPath $temp)) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    }
    finally {
      $result.EndTime = (Get-Date).ToUniversalTime().ToString('o')
      if ($result.ErrorCode -cne 'WhatIfNoWrite') {
        try {
          if (-not (Test-Path -LiteralPath $layout.DeployRoot -PathType Container)) { $null = New-Item -ItemType Directory -Path $layout.DeployRoot -Force }
          $result.ReceiptPath = Join-Path $layout.DeployRoot ("Install-ATAPCoordResidentLauncher-{0}-{1}.json" -f $ModuleVersion, (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
          [IO.File]::WriteAllText($result.ReceiptPath, ($result | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Receipt could not be written: $($_.Exception.Message)"
        }
      }
    }
    if ($result.ExitStatus -ne 0) { throw $result.ErrorCode }
    $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

function Get-ATAPCoordResidentLauncherLayout {
  <#
  .SYNOPSIS
  Fixed source, destination, signer and receipt locations for Install-ATAPCoordResidentLauncher.
  .DESCRIPTION
  Not exported and not request-settable. Kept as a function so tests can mock it to TestDrive paths
  instead of touching Program Files.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param()
  begin { $fn = 'Get-ATAPCoordResidentLauncherLayout'; $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' }
  process {
    $repoRoot = if (Get-Command -Name 'Get-RepositoryRoot' -ErrorAction SilentlyContinue) { try { Get-RepositoryRoot } catch { $null } } else { $null }
    if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
    # The custody record comes from host settings, never from the request.
    $custodyPath = $null
    $keys = Get-Variable -Name configRootKeys -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $settings = Get-Variable -Name settings -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    if ($keys -and $settings) {
      $key = $keys['OrchestrationCustodyRecordPathConfigRootKey']
      if ($key -and $settings.ContainsKey($key)) { $custodyPath = [string]$settings[$key] }
    }
    [PSCustomObject]@{
      ModulesRoot          = 'C:\Program Files\PowerShell\Modules'
      ModuleName           = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
      RelativeLauncherPath = 'Resources\Resident\Start-CoordClerkResident.ps1'
      DestinationPath      = 'C:\Program Files\ATAP\Orchestration\Start-CoordClerkResident.ps1'
      SourceRecordPath     = 'C:\Program Files\ATAP\Orchestration\Start-CoordClerkResident.ps1.source.json'
      SignerThumbprint     = '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E'
      CustodyPath          = $custodyPath
      DeployRoot           = Join-Path $repoRoot '_generated\deploy'
    }
  }
  end {}
}

function Get-ATAPCoordLauncherCustodyPin {
  <#
  .SYNOPSIS
  Reads custody's admitted Orchestration version and its pinned bundled-launcher digest (read only).
  .DESCRIPTION
  Throws CoordLauncherCustodyUnavailable when the custody record is unset, missing or unreadable, and
  CoordLauncherVersionNotAdmitted when it admits no package. The launcher digest is $null when the
  admitted inventory does not pin exactly one bundled launcher.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param([AllowEmptyString()][AllowNull()][string]$CustodyPath)
  begin { $fn = 'Get-ATAPCoordLauncherCustodyPin'; $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' }
  process {
    if ([string]::IsNullOrWhiteSpace($CustodyPath) -or -not [IO.Path]::IsPathFullyQualified($CustodyPath) -or -not (Test-Path -LiteralPath $CustodyPath -PathType Leaf)) { throw 'CoordLauncherCustodyUnavailable' }
    try { $custody = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($CustodyPath)) -AsHashtable -Depth 70 } catch { throw 'CoordLauncherCustodyUnavailable' }
    if ($custody -isnot [Collections.IDictionary] -or $custody['admissionMode'] -cne 'Established') { throw 'CoordLauncherCustodyUnavailable' }
    $package = $custody['package']
    if ($package -isnot [Collections.IDictionary] -or $package['moduleVersion'] -isnot [string] -or $package['moduleVersion'] -cnotmatch '\A\d+\.\d+\.\d+\z') { throw 'CoordLauncherVersionNotAdmitted' }
    $pins = @(@($package['files']) | Where-Object { $_ -is [Collections.IDictionary] -and $_['path'] -ceq 'Resources/Resident/Start-CoordClerkResident.ps1' })
    $digest = if ($pins.Count -eq 1 -and $pins[0]['digest'] -is [string] -and $pins[0]['digest'] -cmatch '\A[0-9A-Fa-f]{64}\z') { $pins[0]['digest'] } else { $null }
    [PSCustomObject]@{ ModuleVersion = $package['moduleVersion']; LauncherSha256 = $digest }
  }
  end {}
}

function Get-ATAPCoordLauncherInstalledSource {
  <#
  .SYNOPSIS
  Establishes which Orchestration version the installed fixed-path launcher came from, or $null.
  .DESCRIPTION
  First the protected source record beside the launcher, when its Sha256 equals the installed bytes;
  otherwise the highest installed AllUsers version whose bundled launcher has exactly those bytes.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param([Parameter(Mandatory)]$Layout, [Parameter(Mandatory)][string]$InstalledSha256)
  begin { $fn = 'Get-ATAPCoordLauncherInstalledSource'; $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' }
  process {
    if ($Layout.SourceRecordPath -and (Test-Path -LiteralPath $Layout.SourceRecordPath -PathType Leaf)) {
      try {
        $record = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($Layout.SourceRecordPath)) -AsHashtable
        if ($record['ModuleVersion'] -is [string] -and $record['ModuleVersion'] -cmatch '\A\d+\.\d+\.\d+\z' -and
            [string]::Equals([string]$record['Sha256'], $InstalledSha256, [StringComparison]::OrdinalIgnoreCase)) { return $record['ModuleVersion'] }
      } catch { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Launcher source record unreadable; falling back to the installed versions.' }
    }
    $base = Join-Path $Layout.ModulesRoot $Layout.ModuleName
    if (-not (Test-Path -LiteralPath $base -PathType Container)) { return $null }
    $found = @(Get-ChildItem -LiteralPath $base -Directory | Where-Object { $_.Name -cmatch '\A\d+\.\d+\.\d+\z' } | Where-Object {
        $bundled = Join-Path $_.FullName $Layout.RelativeLauncherPath
        (Test-Path -LiteralPath $bundled -PathType Leaf) -and [string]::Equals((Get-FileHash -LiteralPath $bundled -Algorithm SHA256).Hash, $InstalledSha256, [StringComparison]::OrdinalIgnoreCase)
      } | Sort-Object { [version]$_.Name } -Descending)
    if ($found.Count) { return $found[0].Name }
    $null
  }
  end {}
}

function New-ATAPCoordLauncherProtectedAcl {
  <#
  .SYNOPSIS
  Builds the launcher's protected file ACL: owner Administrators; Administrators and SYSTEM FullControl;
  Users ReadAndExecute; inheritance disabled.
  #>
  [CmdletBinding()]
  [OutputType([System.Security.AccessControl.FileSecurity])]
  param()
  begin { $fn = 'New-ATAPCoordLauncherProtectedAcl'; $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' }
  process {
    $admins = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $acl = [System.Security.AccessControl.FileSecurity]::new()
    $acl.SetOwner($admins)
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @(
        @('S-1-5-32-544', 'FullControl'),
        @('S-1-5-18', 'FullControl'),
        @('S-1-5-32-545', 'ReadAndExecute'))) {
      $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($rule[0]), $rule[1], 'Allow'))
    }
    , $acl
  }
  end {}
}
