function Write-ParityJsonFile {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [Parameter(Mandatory = $true)]
    [object] $InputObject
  )

  begin {
    $fn = 'Write-ParityJsonFile'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Writing JSON payload atomically to '$Path'."
  }

  process {
    $temporaryPath = $null
    try {
      if (-not $PSCmdlet.ShouldProcess($Path, 'Write parity JSON file atomically')) {
        return
      }

      $parent = Split-Path -Path $Path -Parent
      if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
      }

      $temporaryPath = Join-Path $parent ".$([IO.Path]::GetFileName($Path)).$([guid]::NewGuid().ToString('N')).tmp"
      $json = $InputObject | ConvertTo-Json -Depth 8
      $encoding = [Text.UTF8Encoding]::new($false)
      [IO.File]::WriteAllText($temporaryPath, "$json$([Environment]::NewLine)", $encoding)
      [IO.File]::Move($temporaryPath, $Path, $true)
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to write JSON payload to '$Path'. Exception: $($_.Exception.Message)"
      throw
    } finally {
      if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
      }
    }
  }

  end {
  }
}
