function Invoke-ParityAudit {
<#
.SYNOPSIS
Writes a local parity audit JSON snapshot.

.DESCRIPTION
Captures deterministic host parity surfaces into a timestamped JSON snapshot in
ParityState. The scope includes OS, PowerShell, selected service state, SMB shares,
ParityState files, SQL instance/version/login/permission/Agent-job/endpoint/path
surfaces, and Chocolatey, pip, npm, and NuGet-managed package versions. Packages
with the same normalized name under multiple managers produce action-required
conflict surfaces.

.PARAMETER StatePath
Local ParityState folder where the snapshot is written.

.PARAMETER HostName
Host name to record in the snapshot.

.PARAMETER OutputPath
Optional explicit snapshot output path.

.PARAMETER PackageManagerProfiles
Explicit identity and profile-path records used to collect pip, npm, and NuGet
tool inventories. Each record must contain Identity and may contain PipPath,
NpmPrefix, and NuGetToolPath. The audit never derives these paths from the
identity running the audit.

.PARAMETER ExpectedSurfaceMinimumCounts
Minimum required row count by category. The default requires OS, PowerShell,
three service rows, SQL, PackageManager, Shares, and ParityState. Missing or thin coverage is written into the
diagnostic snapshot as AuditCoverageFinding rows before the audit throws.

.OUTPUTS
PSCustomObject.

.EXAMPLE
Invoke-ParityAudit -StatePath C:\ProgramData\ATAP\ParityState -HostName utat022
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string] $StatePath = 'C:\ProgramData\ATAP\ParityState',

    [string] $HostName = $env:COMPUTERNAME,

    [string] $OutputPath,

    [object[]] $PackageManagerProfiles = @(),

    [hashtable] $ExpectedSurfaceMinimumCounts = @{
      OS = 1
      PowerShell = 1
      Services = 3
      SQL = 1
      PackageManager = 1
      Shares = 1
      ParityState = 1
    }
  )

  begin {
    $fn = 'Invoke-ParityAudit'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting parity audit snapshot.'
  }

  process {
    try {
      New-ParityDirectory -Path $StatePath
      $timestampUtc = (Get-Date).ToUniversalTime()
      if (-not $OutputPath) {
        $OutputPath = Get-ParityAuditSnapshotPath -StatePath $StatePath -HostName $HostName -TimestampUtc $timestampUtc
      }

      $surfaces = [System.Collections.Generic.List[object]]::new()
      $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
      if ($os) {
        $surfaces.Add([pscustomobject] @{
            Category = 'OS'
            Item = 'CaptionVersionBuild'
            Value = "$($os.Caption) $($os.Version) Build $($os.BuildNumber)"
            Source = 'Win32_OperatingSystem'
          })
      }

      $surfaces.Add([pscustomobject] @{
          Category = 'PowerShell'
          Item = 'PSVersion'
          Value = $PSVersionTable.PSVersion.ToString()
          Source = 'PSVersionTable'
        })

      # Win32_Service, not Get-Service: it is the surface the least-privilege matrix names, and
      # both were equally denied until Task 14.72 granted read-only SCM plus per-service query
      # rights. Enumerate once rather than querying per name, so one denial cannot silently
      # degrade a single row to '<missing>' while the others succeed.
      $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue)
      foreach ($serviceName in @('W32Time', 'WinRM', 'sshd')) {
        $service = $services | Where-Object Name -eq $serviceName | Select-Object -First 1
        $surfaces.Add([pscustomobject] @{
            Category = 'Services'
            Item = $serviceName
            Value = if ($service) { [string] $service.State } else { '<missing>' }
            Source = 'Win32_Service'
          })
      }

      foreach ($sqlSurface in @(Get-SqlParitySurfaces)) {
        $surfaces.Add($sqlSurface)
      }

      foreach ($packageSurface in @(Get-PackageManagerParitySurfaces -HostName $HostName -PackageManagerProfiles $PackageManagerProfiles)) {
        $surfaces.Add($packageSurface)
      }

      $shareSource = if (Get-Command -Name 'Get-SmbShare' -ErrorAction SilentlyContinue) {
        'Get-SmbShare'
      } else {
        'Win32_Share'
      }
      $shareNames = if ($shareSource -eq 'Get-SmbShare') {
        @(Get-SmbShare -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object)
      } else {
        @(Get-CimInstance -ClassName Win32_Share -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object)
      }
      $surfaces.Add([pscustomobject] @{
          Category = 'Shares'
          Item = 'SmbShareNames'
          Value = ($shareNames -join ';')
          Source = $shareSource
        })

      $stateFiles = @(
        Get-ChildItem -LiteralPath $StatePath -File -ErrorAction SilentlyContinue |
          ForEach-Object {
            $name = $_.Name
            if ($name -match '^(?i)(ParityAudit|DriftReport)\.') {
              return
            }

            $normalizedName = $name -replace "(?i)$([regex]::Escape($HostName))", '<host>'
            if ($normalizedName -match '^(ChangeAck|ChangeJournal|HostMarker|LocalWriteVerification)\.') {
              $normalizedName
            }
          } |
          Sort-Object -Unique
      )
      $surfaces.Add([pscustomobject] @{
          Category = 'ParityState'
          Item = 'NormalizedFileNames'
          Value = ($stateFiles -join ';')
          Source = 'Get-ChildItem'
        })

      if ($null -eq $ExpectedSurfaceMinimumCounts) {
        throw 'ExpectedSurfaceMinimumCounts cannot be null.'
      }
      if ($ExpectedSurfaceMinimumCounts.Count -eq 0) {
        throw 'ExpectedSurfaceMinimumCounts must contain at least one category.'
      }

      $coverageFindings = [System.Collections.Generic.List[object]]::new()
      foreach ($expectedCategory in @($ExpectedSurfaceMinimumCounts.Keys | Sort-Object)) {
        if ([string]::IsNullOrWhiteSpace([string]$expectedCategory)) {
          throw 'Expected surface minimum category keys must be non-empty.'
        }
        $minimumCount = 0
        if (-not [int]::TryParse([string]$ExpectedSurfaceMinimumCounts[$expectedCategory], [ref]$minimumCount) -or $minimumCount -lt 1) {
          throw "Expected minimum count for category '$expectedCategory' must be at least one."
        }

        $actualCount = @($surfaces | Where-Object { $_.Category -eq $expectedCategory }).Count
        if ($actualCount -ge $minimumCount) {
          continue
        }

        $classification = if ($actualCount -eq 0) { 'Missing' } else { 'Thin' }
        $finding = [pscustomobject]@{
          Category = 'AuditCoverageFinding'
          Item = [string]$expectedCategory
          Value = "$classification;ActualCount=$actualCount;ExpectedMinimumCount=$minimumCount"
          Source = 'ExpectedSurfaceMinimumCounts'
        }
        $coverageFindings.Add($finding)
        $surfaces.Add($finding)
      }

      $snapshot = [pscustomobject] @{
        SchemaVersion = 1
        HostName = $HostName.ToLowerInvariant()
        CapturedAtUtc = $timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
        StatePath = $StatePath
        Surfaces = @($surfaces)
      }

      if ($PSCmdlet.ShouldProcess($OutputPath, 'Write parity audit snapshot')) {
        $snapshot | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $OutputPath -Encoding utf8
      }

      if ($coverageFindings.Count -gt 0) {
        $coverageSummary = @($coverageFindings | ForEach-Object { "$($_.Item)=$($_.Value)" }) -join '; '
        throw "Parity audit surface coverage is inadequate. Diagnostic snapshot: '$OutputPath'. Findings: $coverageSummary"
      }

      $snapshot | Add-Member -NotePropertyName SnapshotPath -NotePropertyValue $OutputPath -PassThru
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Parity audit did not complete successfully. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed parity audit snapshot.'
  }
}
