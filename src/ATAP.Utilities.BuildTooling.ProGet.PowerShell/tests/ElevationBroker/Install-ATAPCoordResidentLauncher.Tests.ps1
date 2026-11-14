BeforeAll {
    Import-Module PSFramework -ErrorAction Stop
    $script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $script:ModuleRoot 'private\Test-ATAPModuleAllUsersElevated.ps1')
    . (Join-Path $script:ModuleRoot 'public\Install-ATAPCoordResidentLauncher.ps1')
    $script:Signer = '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E'
    $script:ModuleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'

    function script:New-LauncherFixture {
        param([string]$Version = '0.1.17', [string]$Content = "# signed launcher fixture`n")
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $versionDir = Join-Path $root "Modules\$script:ModuleName\$Version"
        $null = New-Item -ItemType Directory -Path (Join-Path $versionDir 'Resources\Resident') -Force
        Set-Content -LiteralPath (Join-Path $versionDir "$script:ModuleName.psd1") -Value "@{ ModuleVersion = '$Version' }"
        $launcher = Join-Path $versionDir 'Resources\Resident\Start-CoordClerkResident.ps1'
        [IO.File]::WriteAllText($launcher, $Content)
        $hash = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash
        $custody = Join-Path $root 'Custody\custody.json'
        $fixture = [pscustomobject]@{
            Root = $root; VersionDir = $versionDir; Launcher = $launcher; Hash = $hash; Custody = $custody
            Layout = [pscustomobject]@{
                ModulesRoot = Join-Path $root 'Modules'; ModuleName = $script:ModuleName
                RelativeLauncherPath = 'Resources\Resident\Start-CoordClerkResident.ps1'
                DestinationPath = Join-Path $root 'ProgramFiles\ATAP\Orchestration\Start-CoordClerkResident.ps1'
                SourceRecordPath = Join-Path $root 'ProgramFiles\ATAP\Orchestration\Start-CoordClerkResident.ps1.source.json'
                SignerThumbprint = $script:Signer; CustodyPath = $custody; DeployRoot = Join-Path $root 'deploy'
            }
        }
        script:Set-CustodyAdmission $fixture $Version $hash.ToLowerInvariant()
        $fixture
    }

    function script:Set-CustodyAdmission($Fixture, [string]$Version, [string]$Digest) {
        $null = New-Item -ItemType Directory -Path (Split-Path $Fixture.Custody) -Force
        $files = @([ordered]@{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; digest = $Digest }, [ordered]@{ path = 'other.ps1'; digest = ('a' * 64) })
        [IO.File]::WriteAllText($Fixture.Custody, ([ordered]@{ admissionMode = 'Established'; package = [ordered]@{ moduleVersion = $Version; files = $files } } | ConvertTo-Json -Depth 6))
    }

    function script:Add-InstalledVersion($Fixture, [string]$Version, [string]$Content) {
        $dir = Join-Path $Fixture.Layout.ModulesRoot "$script:ModuleName\$Version\Resources\Resident"
        $null = New-Item -ItemType Directory -Path $dir -Force
        [IO.File]::WriteAllText((Join-Path $dir 'Start-CoordClerkResident.ps1'), $Content)
    }
}

Describe 'Install-ATAPCoordResidentLauncher' {
    BeforeEach {
        $script:f = New-LauncherFixture
        $script:appliedAcl = $null
        Mock Get-ATAPCoordResidentLauncherLayout { $script:f.Layout }
        Mock Test-ATAPModuleAllUsersElevated { $true }
        Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Thumbprint = $script:Signer } } }
        Mock Set-Acl { $script:appliedAcl = $AclObject }
        Mock Get-Acl { $script:appliedAcl }
    }

    It 'copies the bundled launcher to the fixed path, applies the ACL and writes a receipt' {
        $r = Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false
        $r.ExitStatus | Should -Be 0
        $r.BeforeSha256 | Should -BeNullOrEmpty
        $r.AfterSha256 | Should -Be $script:f.Hash
        (Get-FileHash -LiteralPath $script:f.Layout.DestinationPath).Hash | Should -Be $script:f.Hash
        # Launcher temp + launcher, then source-record temp + source record.
        Should -Invoke Set-Acl -Times 4 -Exactly
        Test-Path -LiteralPath $r.ReceiptPath | Should -BeTrue
        (Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json).AfterSha256 | Should -Be $script:f.Hash
        @(Get-ChildItem -LiteralPath (Split-Path $script:f.Layout.DestinationPath) -Filter '*.tmp-*').Count | Should -Be 0
    }

    It 'replaces an existing copy atomically and preserves a hash-named preimage' {
        # The installed copy came from 0.1.16 (established by matching the installed bytes).
        script:Add-InstalledVersion $script:f '0.1.16' "# older launcher`n"
        $null = New-Item -ItemType Directory -Path (Split-Path $script:f.Layout.DestinationPath) -Force
        [IO.File]::WriteAllText($script:f.Layout.DestinationPath, "# older launcher`n")
        $old = (Get-FileHash -LiteralPath $script:f.Layout.DestinationPath).Hash
        $r = Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false
        $r.BeforeSha256 | Should -Be $old
        $r.InstalledFromVersion | Should -Be '0.1.16'
        $r.AfterSha256 | Should -Be $script:f.Hash
        (Get-FileHash -LiteralPath $r.PreimagePath).Hash | Should -Be $old
    }

    It 'writes a protected source record naming the installed version and bytes' {
        $r = Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false
        $record = Get-Content -LiteralPath $script:f.Layout.SourceRecordPath -Raw | ConvertFrom-Json
        $record.ModuleVersion | Should -BeExactly '0.1.17'
        $record.Sha256 | Should -Be $script:f.Hash
        $r.SourceRecordPath | Should -Be $script:f.Layout.SourceRecordPath
        @(Get-ChildItem -LiteralPath (Split-Path $script:f.Layout.DestinationPath) -Filter '*.tmp-*').Count | Should -Be 0
    }

    It 'reinstalls the same version (repair) when the source record matches' {
        $null = Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false
        $r = Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false
        $r.ExitStatus | Should -Be 0
        $r.InstalledFromVersion | Should -BeExactly '0.1.17'
    }

    It 'refuses a launcher from a version custody does not admit (M1)' {
        script:Set-CustodyAdmission $script:f '0.1.16' $script:f.Hash
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherVersionNotAdmitted'
        Test-Path -LiteralPath $script:f.Layout.DestinationPath | Should -BeFalse
        Should -Invoke Set-Acl -Times 0 -Exactly
    }

    It 'refuses a launcher digest custody''s inventory does not pin (M1)' {
        script:Set-CustodyAdmission $script:f '0.1.17' ('b' * 64)
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherDigestNotAdmitted'
        Test-Path -LiteralPath $script:f.Layout.DestinationPath | Should -BeFalse
    }

    It 'refuses when the custody record is unset or unreadable' {
        $script:f.Layout.CustodyPath = $null
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherCustodyUnavailable'
        $script:f.Layout.CustodyPath = $script:f.Custody
        [IO.File]::WriteAllText($script:f.Custody, '{ not json')
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherCustodyUnavailable'
        Test-Path -LiteralPath $script:f.Layout.DestinationPath | Should -BeFalse
    }

    It 'refuses a downgrade below the installed launcher''s source version (M1)' {
        $null = New-Item -ItemType Directory -Path (Split-Path $script:f.Layout.DestinationPath) -Force
        [IO.File]::WriteAllText($script:f.Layout.DestinationPath, "# 0.1.18 launcher`n")
        $installed = (Get-FileHash -LiteralPath $script:f.Layout.DestinationPath).Hash
        [IO.File]::WriteAllText($script:f.Layout.SourceRecordPath, ([ordered]@{ ModuleVersion = '0.1.18'; Sha256 = $installed } | ConvertTo-Json))
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherDowngradeRefused'
        (Get-FileHash -LiteralPath $script:f.Layout.DestinationPath).Hash | Should -Be $installed
        Should -Invoke Set-Acl -Times 0 -Exactly
    }

    It 'refuses when the installed launcher''s source version cannot be established' {
        $null = New-Item -ItemType Directory -Path (Split-Path $script:f.Layout.DestinationPath) -Force
        [IO.File]::WriteAllText($script:f.Layout.DestinationPath, "# hand-placed launcher`n")
        $installed = (Get-FileHash -LiteralPath $script:f.Layout.DestinationPath).Hash
        # A stale record (bytes differ) is ignored, not trusted.
        [IO.File]::WriteAllText($script:f.Layout.SourceRecordPath, ([ordered]@{ ModuleVersion = '0.1.10'; Sha256 = ('C' * 64) } | ConvertTo-Json))
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherInstalledSourceUnknown'
        (Get-FileHash -LiteralPath $script:f.Layout.DestinationPath).Hash | Should -Be $installed
    }

    It 'rejects a ModuleVersion or hash with a trailing newline at binding (L1)' {
        { Install-ATAPCoordResidentLauncher -ModuleVersion "0.1.17`n" -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 ($script:f.Hash + "`n") -Confirm:$false } | Should -Throw
        Test-Path -LiteralPath $script:f.Layout.DestinationPath | Should -BeFalse
        # The old '$' anchors would have accepted both.
        "0.1.17`n" | Should -Match '^\d+\.\d+\.\d+$'
    }

    It 'applies a protected ACL: owner Administrators, Administrators and SYSTEM full, Users read and execute' {
        $null = Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false
        $script:appliedAcl.AreAccessRulesProtected | Should -BeTrue
        $script:appliedAcl.GetOwner([Security.Principal.SecurityIdentifier]).Value | Should -Be 'S-1-5-32-544'
        $rules = @($script:appliedAcl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
        $rules.Count | Should -Be 3
        ($rules | Where-Object { $_.IdentityReference.Value -eq 'S-1-5-32-545' }).FileSystemRights.ToString() | Should -Match 'ReadAndExecute'
        @($rules | Where-Object { $_.IdentityReference.Value -in 'S-1-5-32-544', 'S-1-5-18' -and $_.FileSystemRights -eq 'FullControl' }).Count | Should -Be 2
        @($rules | Where-Object { $_.IsInherited }).Count | Should -Be 0
    }

    It 'refuses when not elevated' {
        Mock Test-ATAPModuleAllUsersElevated { $false }
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherNotElevated'
        Test-Path -LiteralPath $script:f.Layout.DestinationPath | Should -BeFalse
    }

    It 'refuses when the module version is not installed' {
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.99' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherModuleNotInstalled'
    }

    It 'refuses when the bundled launcher is missing' {
        Remove-Item -LiteralPath $script:f.Launcher
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherModuleNotInstalled'
    }

    It 'refuses an ambiguous install (two folders for the same version)' {
        $null = New-Item -ItemType Directory -Path (Join-Path $script:f.Layout.ModulesRoot "$script:ModuleName\0.1.17.0") -Force
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherInstallAmbiguous'
    }

    It 'refuses an ambiguous install (manifest declares a different version)' {
        Set-Content -LiteralPath (Join-Path $script:f.VersionDir "$script:ModuleName.psd1") -Value "@{ ModuleVersion = '0.1.16' }"
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherInstallAmbiguous'
    }

    It 'refuses a hash mismatch and writes nothing to the destination' {
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 ('0' * 64) -Confirm:$false } | Should -Throw 'CoordLauncherSourceHashMismatch'
        Test-Path -LiteralPath $script:f.Layout.DestinationPath | Should -BeFalse
        Should -Invoke Set-Acl -Times 0 -Exactly
    }

    It 'refuses an invalid signature' {
        Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = 'NotSigned'; SignerCertificate = $null } }
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherSignatureInvalid'
    }

    It 'refuses a valid signature from the wrong signer' {
        Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Thumbprint = ('A' * 40) } } }
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherSignerMismatch'
        Test-Path -LiteralPath $script:f.Layout.DestinationPath | Should -BeFalse
    }

    It 'refuses when the applied ACL does not read back as protected' {
        Mock Get-Acl { [System.Security.AccessControl.FileSecurity]::new() }
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherAclVerificationFailed'
    }

    It 'writes a receipt with the refusal code' {
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 ('0' * 64) -Confirm:$false } | Should -Throw
        $receipt = @(Get-ChildItem -LiteralPath $script:f.Layout.DeployRoot -Filter 'Install-ATAPCoordResidentLauncher-*.json')
        $receipt.Count | Should -Be 1
        (Get-Content -LiteralPath $receipt[0].FullName -Raw | ConvertFrom-Json).ErrorCode | Should -Be 'CoordLauncherSourceHashMismatch'
    }

    It 'refuses when the destination path passes through a reparse point (TestDrive junction)' {
        $real = Join-Path $script:f.Root 'RealProgramFiles'
        $null = New-Item -ItemType Directory -Path $real -Force
        $junction = Join-Path $script:f.Root 'JunctionProgramFiles'
        $null = New-Item -ItemType Junction -Path $junction -Target $real
        $script:f.Layout.DestinationPath = Join-Path $junction 'ATAP\Orchestration\Start-CoordClerkResident.ps1'
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherReparsePathRefused'
        Test-Path -LiteralPath (Join-Path $real 'ATAP') | Should -BeFalse
        Should -Invoke Set-Acl -Times 0 -Exactly
    }

    It 'refuses when the source module root passes through a reparse point (TestDrive junction)' {
        $junction = Join-Path $script:f.Root 'JunctionModules'
        $null = New-Item -ItemType Junction -Path $junction -Target $script:f.Layout.ModulesRoot
        $script:f.Layout.ModulesRoot = $junction
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw 'CoordLauncherReparsePathRefused'
        Test-Path -LiteralPath $script:f.Layout.DestinationPath | Should -BeFalse
    }

    It 'writes nothing under -WhatIf' {
        $r = Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17' -ExpectedSha256 $script:f.Hash -WhatIf
        $r.ErrorCode | Should -Be 'WhatIfNoWrite'
        Test-Path -LiteralPath $script:f.Layout.DestinationPath | Should -BeFalse
        Should -Invoke Set-Acl -Times 0 -Exactly
    }

    It 'takes no caller-supplied path: only ModuleVersion and ExpectedSha256 are parameters' {
        $names = (Get-Command Install-ATAPCoordResidentLauncher).Parameters.Keys | Where-Object { $_ -notin [Management.Automation.PSCmdlet]::CommonParameters -and $_ -notin [Management.Automation.PSCmdlet]::OptionalCommonParameters }
        @($names | Sort-Object) | Should -Be @('ExpectedSha256', 'ModuleVersion')
    }

    It 'rejects path-like or prerelease ModuleVersion values at binding' {
        { Install-ATAPCoordResidentLauncher -ModuleVersion '..\0.1.17' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw
        { Install-ATAPCoordResidentLauncher -ModuleVersion '0.1.17-beta' -ExpectedSha256 $script:f.Hash -Confirm:$false } | Should -Throw
    }
}

Describe 'Broker config template entry install-coord-resident-launcher' {
    BeforeAll {
        $script:Config = Get-Content -LiteralPath (Join-Path $script:ModuleRoot 'Resources\ElevationBroker\ElevationBroker-config.template.json') -Raw | ConvertFrom-Json
        $script:Entry = @($script:Config.installers | Where-Object id -eq 'install-coord-resident-launcher')
    }

    It 'is registered exactly once as a module command from the trusted root' {
        $script:Entry.Count | Should -Be 1
        $script:Entry[0].commandType | Should -Be 'module'
        $script:Entry[0].moduleName | Should -Be 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
        $script:Entry[0].commandName | Should -Be 'Install-ATAPCoordResidentLauncher'
        @($script:Entry[0].trustedModuleRoots) | Should -Be @('C:\Program Files\PowerShell\Modules')
        { [version]$script:Entry[0].minimumModuleVersion } | Should -Not -Throw
    }

    It 'allows exactly ModuleVersion and ExpectedSha256, both required' {
        @($script:Entry[0].allowedParameters.name | Sort-Object) | Should -Be @('ExpectedSha256', 'ModuleVersion')
        @($script:Entry[0].allowedParameters | Where-Object { -not $_.required }).Count | Should -Be 0
    }

    It 'patterns reject traversal, prerelease and non-hex values' {
        $v = ($script:Entry[0].allowedParameters | Where-Object name -eq 'ModuleVersion').pattern
        $h = ($script:Entry[0].allowedParameters | Where-Object name -eq 'ExpectedSha256').pattern
        '0.1.17' | Should -Match $v
        '..\0.1.17' | Should -Not -Match $v
        '0.1.17-beta' | Should -Not -Match $v
        # L1: \A...\z, so a trailing newline no longer passes the broker's -notmatch check.
        "0.1.17`n" | Should -Not -Match $v
        $v | Should -BeExactly '\A\d+\.\d+\.\d+\z'
        ('A' * 64) | Should -Match $h
        ('G' * 64) | Should -Not -Match $h
    }

    It 'names the exported command in the module manifest' {
        (Import-PowerShellDataFile -LiteralPath (Join-Path $script:ModuleRoot 'ATAP.Utilities.BuildTooling.ProGet.PowerShell.psd1')).FunctionsToExport | Should -Contain 'Install-ATAPCoordResidentLauncher'
    }

    It 'names the exported command in the psm1 Export-ModuleMember -Function list too' {
        # The source psm1 keeps its own explicit list; a name missing there is not exported, and the
        # broker's Resolve-BrokerModuleCommand would refuse the entry with "does not export".
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:ModuleRoot 'ATAP.Utilities.BuildTooling.ProGet.PowerShell.psm1'), [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0
        $calls = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Export-ModuleMember' }, $true))
        $calls.Count | Should -Be 1
        $elements = $calls[0].CommandElements
        $index = [array]::IndexOf(@($elements | ForEach-Object { if ($_ -is [Management.Automation.Language.CommandParameterAst]) { $_.ParameterName } else { $null } }), 'Function')
        $index | Should -BeGreaterThan 0
        $names = @($elements[$index + 1].FindAll({ param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object Value)
        $names | Should -Contain 'Install-ATAPCoordResidentLauncher'
        $psd1 = @((Import-PowerShellDataFile -LiteralPath (Join-Path $script:ModuleRoot 'ATAP.Utilities.BuildTooling.ProGet.PowerShell.psd1')).FunctionsToExport)
        @($psd1 | Where-Object { $_ -notin $names }) | Should -BeNullOrEmpty
    }
}
