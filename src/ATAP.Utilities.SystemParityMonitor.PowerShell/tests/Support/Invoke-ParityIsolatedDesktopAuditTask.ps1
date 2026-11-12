function Get-IsolatedDesktopAuditReparseTag {
  param([string] $Path, [hashtable] $Diagnostic = @{})

  $fsutil = Join-Path ([Environment]::SystemDirectory) 'fsutil.exe'
  $Diagnostic.NativeExit = $null
  try {
    $metadata = & $fsutil reparsepoint query $Path 2>&1
  } catch {
    if ($_.Exception -is [System.Management.Automation.NativeCommandExitException]) {
      $Diagnostic.NativeExit = $_.Exception.ExitCode
    }
    $Diagnostic.AbsentTagReason = 'Native query raised an error before tag parsing'
    return
  }

  # Native commands update the global exit code, even inside this function.
  $Diagnostic.NativeExit = $global:LASTEXITCODE
  if ($null -eq $Diagnostic.NativeExit) {
    $Diagnostic.AbsentTagReason = 'Native query produced no exit code'
    return
  }
  if ($Diagnostic.NativeExit -ne 0) {
    $Diagnostic.AbsentTagReason = 'Native query exited unsuccessfully before tag parsing'
    return
  }

  $match = [regex]::Match(($metadata -join [Environment]::NewLine), '(?im)^Reparse Tag Value\s*:\s*(0x[0-9a-f]+)\s*$')
  if ($match.Success) {
    $match.Groups[1].Value
  } else {
    $Diagnostic.AbsentTagReason = 'No parseable tag header in native output'
  }
}

function Assert-IsolatedDesktopAuditLocalItem {
  param([System.IO.FileSystemInfo] $Item)

  if (-not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return }

  $itemContext = "Path='$($Item.FullName)' | Attributes='$($Item.Attributes)' ($([int]$Item.Attributes))"
  try {
    $linkTarget = $Item.ResolveLinkTarget($false)
  } catch {
    throw "The isolated audit could not resolve the reparse item. $itemContext | fsutil exit=not run | tag unavailable: link inspection failed."
  }
  if ($null -ne $linkTarget) {
    throw "The isolated audit refuses redirected paths. $itemContext | fsutil exit=not run | tag unavailable: link target detected."
  }

  # MS-FSCC CLOUD and CLOUD_1 through CLOUD_F vary only in this hex digit.
  $diagnostic = @{}
  $tag = Get-IsolatedDesktopAuditReparseTag -Path $Item.FullName -Diagnostic $diagnostic
  if ($tag -isnot [string] -or $tag -notmatch '\A0x9000[0-9a-f]01a\z') {
    $nativeExit = if ($null -eq $diagnostic.NativeExit) { 'unavailable' } else { $diagnostic.NativeExit }
    $tagContext = if ($tag) { "tag=$tag" } else { "tag unavailable: $($diagnostic.AbsentTagReason)" }
    throw "The isolated audit refuses unsupported reparse points. $itemContext | fsutil exit=$nativeExit | $tagContext."
  }
}

function Get-IsolatedDesktopAuditFixtureRegistration {
  param([string] $CasePath)

  $registry = Get-Variable -Name ATAPOwnedParityTestFixtures -Scope Global -ValueOnly -ErrorAction SilentlyContinue
  if ($registry -is [System.Collections.Generic.Dictionary[string, object]] -and $registry.ContainsKey($CasePath)) {
    $registry[$CasePath]
  }
}

function Assert-IsolatedDesktopAuditDirectory {
  param([string] $Path)

  $parent = Split-Path -Path $Path -Parent
  if ($parent -and $parent -ne $Path) { Assert-IsolatedDesktopAuditDirectory -Path $parent }

  $directory = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if (-not $directory.PSIsContainer) { throw 'The isolated audit requires a local directory.' }
  Assert-IsolatedDesktopAuditLocalItem -Item $directory
  $directory
}

function Assert-IsolatedDesktopAuditOwnedCase {
  param([string] $CasePath, [string] $RepositoryRoot, $Registration)

  $directories = @(Assert-IsolatedDesktopAuditDirectory -Path $casePath | Where-Object {
      $_.FullName -ieq $repositoryRoot -or $_.FullName.StartsWith("$repositoryRoot\", [StringComparison]::OrdinalIgnoreCase)
    })
  $ancestors = @($registration.Ancestors)
  if ($directories.Count -ne $ancestors.Count) { throw 'The registered fixture directory chain changed.' }
  for ($index = 0; $index -lt $directories.Count; $index++) {
    if ($directories[$index].FullName.TrimEnd('\') -ine $ancestors[$index].Path.TrimEnd('\') -or
      $directories[$index].CreationTimeUtc.Ticks -ne $ancestors[$index].CreationTicks) {
      throw 'The registered fixture directory chain changed.'
    }
  }
  $markerPath = Join-Path $casePath '.owned-parity-fixture.json'
  $marker = Get-Item -LiteralPath $markerPath -Force -ErrorAction Stop
  if ($marker.PSIsContainer -or $marker.Length -gt 2048) { throw 'Invalid fixture ownership marker.' }
  Assert-IsolatedDesktopAuditLocalItem -Item $marker
  if ((Get-Content -LiteralPath $markerPath -Raw -Encoding utf8 -ErrorAction Stop) -cne $registration.MarkerJson) {
    throw 'The fixture ownership marker changed.'
  }
}

function Open-IsolatedDesktopAuditStage {
  param([string] $Path)

  [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
}

function Get-IsolatedDesktopAuditExecutable {
  param([string] $Path)

  $null = Assert-IsolatedDesktopAuditDirectory -Path (Split-Path -Path $Path -Parent)
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if ($item.PSIsContainer) { throw 'The desktop executable path is not a file.' }
  Assert-IsolatedDesktopAuditLocalItem -Item $item
  [pscustomobject]@{
    ProductName = $item.VersionInfo.ProductName
    ProductVersion = $item.VersionInfo.ProductVersion
    SHA256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
  }
}

function Invoke-ParityIsolatedDesktopAuditTask {
  <#
  .SYNOPSIS
    Records only the two selected UTAT022 desktop products in an owned case.
  .DESCRIPTION
    Dot-source this file in the process that owns the GUID-N fixture. Supply
    the selected user's SID and exact Antigravity uninstall key name. The
    result file is fixed and must be absent. Failed publication can leave a
    .pending file for diagnosis. Installation reads are local.
  .OUTPUTS
    A result object that also records the two desktop rows in the case.
  #>
  [CmdletBinding()]
  param(
    [AllowEmptyString()][string] $StatePath,
    [string] $RunId,
    [string] $CaseId,
    [string] $OwnerToken,
    [string] $AntigravityUserSid,
    [string] $AntigravityUninstallKeyName
  )

  begin {
    if (-not $IsWindows -or -not [Environment]::Is64BitProcess -or [Environment]::MachineName -ine 'UTAT022') {
      throw 'This isolated desktop audit requires a 64-bit Windows process on UTAT022.'
    }
  }

  process {
    if (-not $PSBoundParameters.ContainsKey('StatePath') -or [string]::IsNullOrWhiteSpace($StatePath)) {
      throw 'An explicit StatePath is required.'
    }
    foreach ($identity in @($RunId, $CaseId, $OwnerToken)) {
      $parsed = [guid]::Empty
      if (-not [guid]::TryParseExact($identity, 'N', [ref]$parsed) -or $parsed -eq [guid]::Empty) {
        throw 'RunId, CaseId and OwnerToken must be nonempty GUIDs in N format.'
      }
    }

    $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
    $fixtureRoot = Join-Path $repositoryRoot '_generated/Sprint0017/17.6.a/StatePathFixtures'
    $casePath = Join-Path $fixtureRoot $RunId.ToLowerInvariant() $CaseId.ToLowerInvariant()
    if ($StatePath -ine $casePath) { throw 'StatePath must be the exact owned run/case path.' }

    $registration = Get-IsolatedDesktopAuditFixtureRegistration -CasePath $casePath
    if ($null -eq $registration -or $registration.Status -ne 'Active' -or
      $registration.RepositoryRoot -ine $repositoryRoot -or $registration.RunId -ine $RunId -or
      $registration.CaseId -ine $CaseId -or $registration.OwnerToken -ine $OwnerToken) {
      throw 'StatePath is not owned by this fixture process and token.'
    }

    Assert-IsolatedDesktopAuditOwnedCase -CasePath $casePath -RepositoryRoot $repositoryRoot -Registration $registration

    $resultName = 'ParityIsolatedDesktopAuditResult.json'
    if (Get-ChildItem -LiteralPath $casePath -Filter $resultName -Force -ErrorAction Stop) {
      throw 'The isolated audit result path already exists.'
    }
    if ($AntigravityUserSid -notmatch '^S-1-5-21-(?:[0-9]+-){3}[0-9]+$' -or
      $AntigravityUninstallKeyName -notmatch '^[A-Za-z0-9{][A-Za-z0-9_.{} -]{0,127}$') {
      throw 'An explicit user SID and literal Antigravity uninstall key name are required.'
    }

    $profile = Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$AntigravityUserSid" -Name ProfileImagePath -ErrorAction Stop
    $selectedProfile = 'C:\Users\whertzing'
    if ($profile.ProfileImagePath -ine $selectedProfile) {
      throw 'The Antigravity SID does not identify the selected UTAT022 profile.'
    }

    $targets = @(
      @{
        Id = 'GitHubCopilotDesktop'; Scope = 'AllUsers'; Product = 'GitHub Copilot'; Publisher = 'GitHub Inc.'
        Key = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{43D3B0DD-4ABF-4CBA-80C7-2403679A3634}'
        Path = 'C:\Program Files\GitHub Copilot\github.exe'; ExpectedVersion = '1.1.35'
      },
      @{
        Id = 'GoogleAntigravityApp'; Scope = 'CurrentUser'; Product = 'Antigravity'; Publisher = 'Google'
        Key = "Registry::HKEY_USERS\$AntigravityUserSid\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AntigravityUninstallKeyName"
        Path = Join-Path $selectedProfile 'AppData\Local\Programs\antigravity\Antigravity.exe'; ExpectedVersion = '2.29.0'
      }
    )

    $rows = foreach ($target in $targets) {
      $installed = Get-ItemProperty -LiteralPath $target.Key -ErrorAction Stop
      $version = [string]$installed.DisplayVersion
      $expectedName = $target.Product
      if ($target.Id -eq 'GoogleAntigravityApp') { $expectedName = "$expectedName $version" }
      if ($installed.DisplayName -ine $expectedName -or $installed.Publisher -ine $target.Publisher -or
        $version -notmatch '^[0-9]+(?:\.[0-9]+){2,3}$') {
        throw "Unexpected registration identity for $($target.Id)."
      }

      $executable = Get-IsolatedDesktopAuditExecutable -Path $target.Path
      if ($executable.ProductName -ine $target.Product -or
        $executable.ProductVersion -notin @($version, "$version.0")) {
        throw "Executable identity or version does not match the registration for $($target.Id)."
      }

      [pscustomobject]@{
        Id = $target.Id
        Scope = $target.Scope
        RegistrationKey = $target.Key
        ExecutablePath = $target.Path
        ExecutableSHA256 = $executable.SHA256
        Version = $version
        ExpectedVersion = $target.ExpectedVersion
        MatchesExpectedVersion = $version -eq $target.ExpectedVersion
      }
    }

    $result = [pscustomobject]@{
      SchemaVersion = 1
      Task = 'ParityIsolatedDesktopAudit'
      HostName = 'UTAT022'
      RunId = $RunId
      CaseId = $CaseId
      CapturedAtUtc = [DateTime]::UtcNow.ToString('o')
      Rows = @($rows)
    }
    $payload = [Text.UTF8Encoding]::new($false).GetBytes(($result | ConvertTo-Json -Depth 5) + [Environment]::NewLine)
    $resultPath = Join-Path $casePath $resultName
    $stagePath = Join-Path $casePath "$resultName.$([guid]::NewGuid().ToString('N')).pending"
    try {
      # Recheck ownership near each path-based operation. These checks do not lease the directory.
      $ErrorActionPreference = 'Stop'
      Assert-IsolatedDesktopAuditOwnedCase -CasePath $casePath -RepositoryRoot $repositoryRoot -Registration $registration
      $stream = Open-IsolatedDesktopAuditStage -Path $stagePath
      $dataError = $null
      try {
        $stream.Write($payload, 0, $payload.Length)
        $stream.Flush($true)
      } catch {
        $dataError = $_
        throw
      } finally {
        try {
          $stream.Dispose()
        } catch {
          if ($null -ne $dataError) {
            throw [AggregateException]::new('Writing or flushing the audit stage and closing it both failed.',
              [Exception[]]@($dataError.Exception, $_.Exception))
          }
          throw
        }
      }

      # Only the closed, flushed stage can acquire the final name. A competing result wins.
      Assert-IsolatedDesktopAuditOwnedCase -CasePath $casePath -RepositoryRoot $repositoryRoot -Registration $registration
      [IO.File]::Move($stagePath, $resultPath, $false)
    } catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }
    $result
  }

  end { }
}
