BeforeAll {
  # Import the module from THIS worktree (tests/Unit -> module root) so the test
  # exercises the worktree's source rather than a stable-repo copy on PSModulePath.
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.PowerShell.psd1'
  Import-Module $script:manifestPath -Force

  # Detect whether this engine can create file symlinks (elevation / Developer Mode).
  # When it cannot, the mutation-path assertions are skipped rather than failed.
  $script:canSymlink = $false
  $script:probeDir = Join-Path ([System.IO.Path]::GetTempPath()) "ps7sym_probe_$([guid]::NewGuid().ToString('N'))"
  New-Item -ItemType Directory -Path $script:probeDir -Force | Out-Null
  try {
    $probeTarget = Join-Path $script:probeDir 'target.txt'
    Set-Content -LiteralPath $probeTarget -Value 'x' -Encoding UTF8
    $probeLink = Join-Path $script:probeDir 'link.txt'
    New-Item -ItemType SymbolicLink -Path $probeLink -Target $probeTarget -ErrorAction Stop | Out-Null
    $script:canSymlink = $true
  } catch {
    $script:canSymlink = $false
  } finally {
    Remove-Item -Path $script:probeDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe 'Set-PowerShell7ProfileSymlink [public]' {
  BeforeEach {
    # Fake GitHub root with stable + sprint ATAP.Utilities / ATAP.IAC roots and a
    # fake PowerShell 7 install directory. Nothing here touches the real machine.
    $script:root = Join-Path ([System.IO.Path]::GetTempPath()) "ps7sym_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:root -Force | Out-Null

    $script:utilSprint = Join-Path $script:root 'ATAP.Utilities-wt-115-Sprint-0010-work-items'
    $script:utilStable = Join-Path $script:root 'ATAP.Utilities'
    $script:iacSprint = Join-Path $script:root 'ATAP.IAC-wt-11-Sprint-0010-work-items'
    $script:iacStable = Join-Path $script:root 'ATAP.IAC'

    $script:profileRel = 'Windows\ProfileTemplates\AllUsersAllHostsV7CoreProfile.ps1'
    $script:hostRel = 'Windows\HostSettings.ps1'

    foreach ($pair in @(
        @($script:iacSprint, $script:profileRel), @($script:iacStable, $script:profileRel),
        @($script:iacSprint, $script:hostRel), @($script:iacStable, $script:hostRel))) {
      $file = Join-Path $pair[0] $pair[1]
      New-Item -ItemType Directory -Path (Split-Path $file -Parent) -Force | Out-Null
      Set-Content -LiteralPath $file -Value '# fixture' -Encoding UTF8
    }
    Set-Content -LiteralPath (Join-Path $script:iacSprint $script:profileRel) -Value '# sprint profile' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $script:iacStable $script:profileRel) -Value '# stable profile' -Encoding UTF8

    $script:ps7 = Join-Path $script:root 'PowerShell7'
    New-Item -ItemType Directory -Path $script:ps7 -Force | Out-Null
  }

  AfterEach {
    Remove-Item -Path $script:root -Recurse -Force -ErrorAction SilentlyContinue
  }

  Context 'Parameter validation' {
    It 'Requires ATAPUtilitiesRoot' {
      { Set-PowerShell7ProfileSymlink -ATAPIACRoot $script:iacStable -PowerShell7Path $script:ps7 } |
        Should -Throw
    }
    It 'Requires ATAPIACRoot' {
      { Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilStable -PowerShell7Path $script:ps7 } |
        Should -Throw
    }
  }

  Context 'Return contract' {
    It 'reports the managed machine profile and HostSettings link' {
      $result = Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilSprint `
        -ATAPIACRoot $script:iacSprint -PowerShell7Path $script:ps7 -WhatIf
      $names = $result.Links.Name
      $names | Should -Contain 'profile.ps1'
      $names | Should -Contain 'HostSettings.ps1'
    }

    It 'Computes sprint targets at start and stable targets at end' {
      $start = Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilSprint `
        -ATAPIACRoot $script:iacSprint -PowerShell7Path $script:ps7 -WhatIf
      ($start.Links | Where-Object Name -EQ 'profile.ps1').Target |
        Should -Be (Join-Path $script:iacSprint $script:profileRel)
      ($start.Links | Where-Object Name -EQ 'HostSettings.ps1').Target |
        Should -Be (Join-Path $script:iacSprint $script:hostRel)

      $end = Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilStable `
        -ATAPIACRoot $script:iacStable -PowerShell7Path $script:ps7 -WhatIf
      ($end.Links | Where-Object Name -EQ 'profile.ps1').Target |
        Should -Be (Join-Path $script:iacStable $script:profileRel)
    }
  }

  Context 'Dangling-target guard' {
    It 'Records TargetMissing and creates no link when the target file is absent' {
      Remove-Item -LiteralPath (Join-Path $script:iacSprint $script:profileRel) -Force
      $result = Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilSprint `
        -ATAPIACRoot $script:iacSprint -PowerShell7Path $script:ps7
      $profileLink = $result.Links | Where-Object Name -EQ 'profile.ps1'
      $profileLink.Action | Should -Be 'TargetMissing'
      $result.Ok | Should -BeFalse
      Test-Path -LiteralPath (Join-Path $script:ps7 'profile.ps1') | Should -BeFalse
    }
  }

  Context 'WhatIf' {
    It 'Performs no mutation under -WhatIf' {
      $result = Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilSprint `
        -ATAPIACRoot $script:iacSprint -PowerShell7Path $script:ps7 -WhatIf
      $result.DryRun | Should -BeTrue
      Test-Path -LiteralPath (Join-Path $script:ps7 'profile.ps1') | Should -BeFalse
      Test-Path -LiteralPath (Join-Path $script:ps7 'HostSettings.ps1') | Should -BeFalse
    }
  }

  Context 'Obsolete-link cleanup' {
    It 'Reports ObsoleteAbsent when the obsolete links do not exist' {
      $result = Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilSprint `
        -ATAPIACRoot $script:iacSprint -PowerShell7Path $script:ps7 -WhatIf
      $obsolete = $result.Links | Where-Object Name -EQ 'global_ConfigRootKeys.ps1'
      $obsolete.Action | Should -Be 'ObsoleteAbsent'
    }
  }

  Context 'Mutation (HostSettings link requires symlink privilege)' {
    It 'copies the machine profile and retargets HostSettings' {
      if (-not $script:canSymlink) { Set-ItResult -Skipped -Because 'engine cannot create symlinks (no elevation / Developer Mode)' }
      $result = Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilSprint `
        -ATAPIACRoot $script:iacSprint -PowerShell7Path $script:ps7
      $result.Ok | Should -BeTrue
      $profileLinkPath = Join-Path $script:ps7 'profile.ps1'
      Test-Path -LiteralPath $profileLinkPath | Should -BeTrue
      (Get-Item -LiteralPath $profileLinkPath -Force).LinkType | Should -BeNullOrEmpty
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($profileLinkPath)) |
        Should -Be ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $script:iacSprint $script:profileRel))))
    }

    It 'Removes an existing obsolete symlink' {
      if (-not $script:canSymlink) { Set-ItResult -Skipped -Because 'engine cannot create symlinks (no elevation / Developer Mode)' }
      $obsoleteTarget = Join-Path $script:utilSprint 'src\ATAP.Utilities.PowerShell\Profiles\global_ConfigRootKeys.ps1'
      New-Item -ItemType Directory -Path (Split-Path $obsoleteTarget -Parent) -Force | Out-Null
      Set-Content -LiteralPath $obsoleteTarget -Value '# obsolete' -Encoding UTF8
      $obsoleteLink = Join-Path $script:ps7 'global_ConfigRootKeys.ps1'
      New-Item -ItemType SymbolicLink -Path $obsoleteLink -Target $obsoleteTarget -Force | Out-Null

      $result = Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilSprint `
        -ATAPIACRoot $script:iacSprint -PowerShell7Path $script:ps7
      ($result.Links | Where-Object Name -EQ 'global_ConfigRootKeys.ps1').Action | Should -Be 'ObsoleteRemoved'
      Test-Path -LiteralPath $obsoleteLink | Should -BeFalse
      # Removing the link must not delete the target file.
      Test-Path -LiteralPath $obsoleteTarget | Should -BeTrue
    }

    It 'replaces a sprint copy with the stable payload across repeated runs' {
      if (-not $script:canSymlink) { Set-ItResult -Skipped -Because 'engine cannot create symlinks (no elevation / Developer Mode)' }
      Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilSprint `
        -ATAPIACRoot $script:iacSprint -PowerShell7Path $script:ps7 | Out-Null
      $second = Set-PowerShell7ProfileSymlink -ATAPUtilitiesRoot $script:utilStable `
        -ATAPIACRoot $script:iacStable -PowerShell7Path $script:ps7
      $second.Ok | Should -BeTrue
      $secondProfile = $second.Links | Where-Object Name -EQ 'profile.ps1'
      $secondProfile.Action | Should -Be 'Copied'
      [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $script:ps7 'profile.ps1'))) |
        Should -Be ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $script:iacStable $script:profileRel))))
    }
  }
}
