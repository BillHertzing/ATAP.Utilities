function Invoke-ParityAudit {
<#
.SYNOPSIS
Writes a local parity audit JSON snapshot.

.DESCRIPTION
Captures deterministic host parity surfaces into a timestamped JSON snapshot in
ParityState. Stage 1 includes OS, PowerShell, selected service state, SMB share
names, and ParityState file inventory. Later sprint tasks can extend this scope.

.PARAMETER StatePath
Local ParityState folder where the snapshot is written.

.PARAMETER HostName
Host name to record in the snapshot.

.PARAMETER OutputPath
Optional explicit snapshot output path.

.OUTPUTS
PSCustomObject.

.EXAMPLE
Invoke-ParityAudit -StatePath C:\ProgramData\ATAP\ParityState -HostName utat022
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string] $StatePath = 'C:\ProgramData\ATAP\ParityState',

    [string] $HostName = $env:COMPUTERNAME,

    [string] $OutputPath
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

      foreach ($serviceName in @('W32Time', 'WinRM', 'sshd')) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        $surfaces.Add([pscustomobject] @{
            Category = 'Services'
            Item = $serviceName
            Value = if ($service) { [string] $service.Status } else { '<missing>' }
            Source = 'Get-Service'
          })
      }

      if (Get-Command -Name 'Get-SmbShare' -ErrorAction SilentlyContinue) {
        $shareNames = @(Get-SmbShare -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object)
        $surfaces.Add([pscustomobject] @{
            Category = 'Shares'
            Item = 'SmbShareNames'
            Value = ($shareNames -join ';')
            Source = 'Get-SmbShare'
          })
      }

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

      $snapshot | Add-Member -NotePropertyName SnapshotPath -NotePropertyValue $OutputPath -PassThru
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to write parity audit snapshot. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed parity audit snapshot.'
  }
}
