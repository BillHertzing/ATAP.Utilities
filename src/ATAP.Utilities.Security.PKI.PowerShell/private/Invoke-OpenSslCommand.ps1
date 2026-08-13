function Invoke-OpenSslCommand {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]] $ArgumentList,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Operation
  )

  begin {
    $fn = 'Invoke-OpenSslCommand'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting OpenSSL operation '$Operation'." -Tag 'Trace'
  }

  process {
    $openSslCommand = Get-Command -Name 'openssl' -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $openSslCommand) {
      throw "OpenSSL is required for '$Operation' but was not found on PATH."
    }

    try {
      $output = @(& $openSslCommand.Source @ArgumentList 2>&1)
      $exitCode = $LASTEXITCODE
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "OpenSSL failed while performing '$Operation': $($_.Exception.Message)"
      throw
    }

    if ($exitCode -ne 0) {
      $summary = ($output | Select-Object -Last 5) -join [Environment]::NewLine
      throw "OpenSSL failed while performing '$Operation' with exit code $exitCode. $summary"
    }

    [PSCustomObject]@{
      Operation = $Operation
      ExitCode = $exitCode
      Output = @($output)
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Completed OpenSSL operation '$Operation'." -Tag 'Trace'
  }
}
