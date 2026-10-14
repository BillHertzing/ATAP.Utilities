function Get-SharedDotNetToolParitySurfaces {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $HostName,

    [Parameter(Mandatory = $true)]
    [string] $StatePath,

    [Parameter(Mandatory = $true)]
    [object] $Policy,

    [object[]] $PackageManagerProfiles = @(),

    [string] $CurrentIdentityName
  )

  begin {
    $fn = 'Get-SharedDotNetToolParitySurfaces'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Collecting shared .NET tool and consumer-evidence surfaces.'
  }

  process {
    if ([int]$Policy.SchemaVersion -ne 1) {
      throw "Shared .NET tool policy has unsupported SchemaVersion '$($Policy.SchemaVersion)'; expected 1."
    }
    $sharedPath = [string]$Policy.SharedPath
    if ([string]::IsNullOrWhiteSpace($sharedPath) -or -not [IO.Path]::IsPathFullyQualified($sharedPath)) {
      throw 'Shared .NET tool policy SharedPath must be a fully qualified path.'
    }
    $sharedPath = [IO.Path]::GetFullPath($sharedPath).TrimEnd('\')
    $tools = @($Policy.Tools | Where-Object { $null -ne $_ })
    $consumers = @($Policy.Consumers | Where-Object { $null -ne $_ })
    if ($tools.Count -eq 0) { throw 'Shared .NET tool policy must contain at least one tool.' }
    if ($consumers.Count -eq 0) { throw 'Shared .NET tool policy must contain at least one consumer.' }

    $toolIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $normalizedTools = foreach ($tool in $tools) {
      $packageId = ([string]$tool.PackageId).Trim()
      $commandName = ([string]$tool.CommandName).Trim()
      $expectedVersion = ([string]$tool.ExpectedVersion).Trim()
      if ([string]::IsNullOrWhiteSpace($packageId) -or [string]::IsNullOrWhiteSpace($commandName) -or [string]::IsNullOrWhiteSpace($expectedVersion)) {
        throw 'Every shared .NET tool must specify PackageId, CommandName, and ExpectedVersion.'
      }
      if (-not $toolIds.Add($packageId)) { throw "Shared .NET tool package '$packageId' is configured more than once." }
      [pscustomobject]@{
        PackageId = $packageId
        CommandName = $commandName
        ExpectedVersion = $expectedVersion
        VersionArguments = if ($tool.PSObject.Properties['VersionArguments']) { @($tool.VersionArguments) } else { @('--version') }
        HelpArguments = if ($tool.PSObject.Properties['HelpArguments']) { @($tool.HelpArguments) } else { @('--help') }
      }
    }

    if ([string]::IsNullOrWhiteSpace($CurrentIdentityName)) {
      try { $CurrentIdentityName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { $CurrentIdentityName = '<unknown>' }
    }
    $surfaces = [System.Collections.Generic.List[object]]::new()
    $liveToolState = @{}

    foreach ($tool in $normalizedTools) {
      $packageStorePath = Join-Path $sharedPath ".store\$($tool.PackageId.ToLowerInvariant())"
      $expectedStorePath = Join-Path $packageStorePath $tool.ExpectedVersion
      $commandPath = Join-Path $sharedPath $tool.CommandName
      $userScopedVersions = @(
        foreach ($profile in @($PackageManagerProfiles)) {
          $profileToolPath = [string]$profile.NuGetToolPath
          if ([string]::IsNullOrWhiteSpace($profileToolPath) -or $profileToolPath.TrimEnd('\') -ieq $sharedPath) { continue }
          $profileStorePath = Join-Path $profileToolPath ".store\$($tool.PackageId.ToLowerInvariant())"
          if (Test-Path -LiteralPath $profileStorePath -PathType Container) {
            Get-ChildItem -LiteralPath $profileStorePath -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
          }
        }
      )
      $installedVersions = if (Test-Path -LiteralPath $packageStorePath -PathType Container) {
        @(Get-ChildItem -LiteralPath $packageStorePath -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object -Unique)
      } else { @() }

      if (-not (Test-Path -LiteralPath $sharedPath -PathType Container)) {
        $status = 'AuditError=SharedPathMissing'
      } elseif (-not (Test-Path -LiteralPath $expectedStorePath -PathType Container)) {
        if ($installedVersions.Count -gt 0) {
          $status = "AuditError=VersionSkew;Installed=$($installedVersions -join ',');Expected=$($tool.ExpectedVersion)"
        } elseif ($userScopedVersions.Count -gt 0) {
          $status = "AuditError=UserScopedOnly;Installed=$($userScopedVersions -join ',');Expected=$($tool.ExpectedVersion)"
        } else { $status = 'AuditError=ToolAbsent' }
      } elseif (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
        $status = 'AuditError=LauncherMissing'
      } else {
        try {
          $versionResult = Invoke-ParityNativeCommand -Command $commandPath -ArgumentList $tool.VersionArguments
          $versionOutput = ((@($versionResult.Output) -join ' ') -replace '\s+', ' ').Trim()
          if ($versionResult.ExitCode -ne 0) {
            $status = "AuditError=Inaccessible;VersionExitCode=$($versionResult.ExitCode)"
          } elseif ($versionOutput -notmatch "(^|\s)$([regex]::Escape($tool.ExpectedVersion))(?=\+|\s|$)") {
            $status = "AuditError=VersionSkew;Observed=$versionOutput;Expected=$($tool.ExpectedVersion)"
          } else {
            $helpResult = Invoke-ParityNativeCommand -Command $commandPath -ArgumentList $tool.HelpArguments
            $status = if ($helpResult.ExitCode -eq 0) { "Available;Version=$($tool.ExpectedVersion);Path=<shared>" } else { "AuditError=Inaccessible;HelpExitCode=$($helpResult.ExitCode)" }
          }
        } catch { $status = "AuditError=Inaccessible;ErrorType=$($_.Exception.GetType().FullName)" }
      }
      $liveToolState[$tool.PackageId] = $status
      $surfaces.Add([pscustomobject]@{ Category = 'SharedDotNetTool'; Item = $tool.PackageId.ToLowerInvariant(); Value = $status; Source = $commandPath })
    }

    $logicalIdentities = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $maximumAgeHours = if ($Policy.PSObject.Properties['EvidenceMaxAgeHours']) { [double]$Policy.EvidenceMaxAgeHours } else { 36 }
    if ($maximumAgeHours -le 0) { throw 'Shared .NET tool policy EvidenceMaxAgeHours must be greater than zero.' }
    foreach ($consumer in $consumers) {
      $logicalIdentity = ([string]$consumer.LogicalIdentity).Trim()
      $actualIdentity = ([string]$consumer.ActualIdentity).Trim()
      $evidenceMode = if ($consumer.PSObject.Properties['EvidenceMode']) { [string]$consumer.EvidenceMode } else { 'EvidenceFile' }
      if ([string]::IsNullOrWhiteSpace($logicalIdentity) -or [string]::IsNullOrWhiteSpace($actualIdentity)) {
        throw 'Every shared .NET tool consumer must specify LogicalIdentity and ActualIdentity.'
      }
      if ($logicalIdentity -match '[/|]' -or -not $logicalIdentities.Add($logicalIdentity)) {
        throw "Shared .NET tool LogicalIdentity '$logicalIdentity' must be unique and cannot contain '/' or '|'."
      }
      if ($evidenceMode -notin @('CurrentProcess', 'EvidenceFile')) {
        throw "Shared .NET tool consumer '$logicalIdentity' has unsupported EvidenceMode '$evidenceMode'."
      }

      if ($evidenceMode -eq 'CurrentProcess') {
        foreach ($tool in $normalizedTools) {
          $value = if ($CurrentIdentityName -ine $actualIdentity) {
            "AuditError=WrongIdentity;Expected=$actualIdentity"
          } elseif ($liveToolState[$tool.PackageId] -notlike 'Available;*') {
            "AuditError=ConsumerInaccessible;ToolStatus=$($liveToolState[$tool.PackageId])"
          } else { "Verified;Version=$($tool.ExpectedVersion);Path=<shared>" }
          $surfaces.Add([pscustomobject]@{ Category = 'SharedDotNetToolConsumer'; Item = "$logicalIdentity/$($tool.PackageId.ToLowerInvariant())"; Value = $value; Source = "CurrentProcess:$CurrentIdentityName" })
        }
        continue
      }

      $evidencePath = [string]$consumer.EvidencePath
      if ([string]::IsNullOrWhiteSpace($evidencePath) -or -not [IO.Path]::IsPathFullyQualified($evidencePath)) {
        throw "EvidencePath for shared .NET tool consumer '$logicalIdentity' must be fully qualified."
      }
      $evidence = $null
      $evidenceError = $null
      if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
        $evidenceError = 'EvidenceMissing'
      } else {
        try {
          $evidence = Read-ParityJsonFile -Path $evidencePath
          if ([int]$evidence.SchemaVersion -ne 1) { $evidenceError = 'EvidenceSchemaUnsupported' }
          elseif ([string]$evidence.HostName -ine $HostName) { $evidenceError = 'WrongHost' }
          elseif ([string]$evidence.LogicalIdentity -ine $logicalIdentity -or [string]$evidence.ActualIdentity -ine $actualIdentity) { $evidenceError = 'WrongIdentity' }
          else {
            $capturedAt = [DateTimeOffset]::Parse([string]$evidence.CapturedAtUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
            if (((Get-Date).ToUniversalTime() - $capturedAt.UtcDateTime).TotalHours -gt $maximumAgeHours) { $evidenceError = 'EvidenceStale' }
          }
        } catch { $evidenceError = "EvidenceUnreadable;ErrorType=$($_.Exception.GetType().FullName)" }
      }

      foreach ($tool in $normalizedTools) {
        $value = if ($evidenceError) { "AuditError=$evidenceError" } else {
          $toolEvidence = @($evidence.Tools | Where-Object { [string]$_.PackageId -ieq $tool.PackageId })
          if ($toolEvidence.Count -ne 1) { 'AuditError=ToolEvidenceMissingOrDuplicate' } else {
            $record = $toolEvidence[0]
            $resolvedPath = [string]$record.ResolvedPath
            if ([string]$record.Version -ne $tool.ExpectedVersion) { "AuditError=VersionSkew;Observed=$($record.Version);Expected=$($tool.ExpectedVersion)" }
            elseif ([int]$record.VersionExitCode -ne 0 -or [int]$record.HelpExitCode -ne 0) { "AuditError=Inaccessible;VersionExitCode=$($record.VersionExitCode);HelpExitCode=$($record.HelpExitCode)" }
            elseif ([string]::IsNullOrWhiteSpace($resolvedPath) -or [IO.Path]::GetFullPath($resolvedPath).TrimEnd('\') -ine (Join-Path $sharedPath $tool.CommandName)) { 'AuditError=UserScopedOnlyOrWrongPath' }
            else { "Verified;Version=$($tool.ExpectedVersion);Path=<shared>" }
          }
        }
        $surfaces.Add([pscustomobject]@{ Category = 'SharedDotNetToolConsumer'; Item = "$logicalIdentity/$($tool.PackageId.ToLowerInvariant())"; Value = $value; Source = "$evidencePath;ActualIdentity=$actualIdentity" })
      }
    }
    @($surfaces | Sort-Object Category, Item, Value -Unique)
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed shared .NET tool and consumer-evidence collection.'
  }
}
