function Invoke-DabCommand {
  <#
  .SYNOPSIS
  Invokes the Data API Builder CLI and returns execution metadata.

  .DESCRIPTION
  Runs a non-stdio DAB command, preserves its output for the caller, and throws when
  the command fails. MCP stdio startup intentionally uses Start-DabMcpServer instead,
  because no PowerShell output may precede MCP protocol messages.

  .OUTPUTS
  PSCustomObject.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $DabPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $ArgumentList
  )

  begin {
    $fn = 'Invoke-DabCommand'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling DAB command '$DabPath $($ArgumentList -join ' ')'."
  }

  process {
    try {
      $output = @(& $DabPath @ArgumentList 2>&1)
      $exitCode = $LASTEXITCODE
      if ($exitCode -ne 0) {
        throw "DAB command failed with exit code ${exitCode}: $DabPath $($ArgumentList -join ' ')"
      }

      [pscustomobject]@{
        Command = $DabPath
        Arguments = @($ArgumentList)
        ExitCode = $exitCode
        Output = @($output | ForEach-Object { [string] $_ })
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "DAB command failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Completed DAB command invocation.'
  }
}
