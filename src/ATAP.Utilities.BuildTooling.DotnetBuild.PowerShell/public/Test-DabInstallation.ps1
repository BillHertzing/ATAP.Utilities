function Test-DabInstallation {
  <#
  .SYNOPSIS
  Tests whether the .NET SDK and Data API Builder global tool are available.

  .DESCRIPTION
  Returns metadata-only availability and version information. It does not install,
  update, or start Data API Builder.

  .OUTPUTS
  PSCustomObject.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param()

  begin {
    $fn = 'Test-DabInstallation'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Testing Data API Builder installation.'
  }

  process {
    try {
      $dotnet = Get-Command -Name 'dotnet' -ErrorAction SilentlyContinue
      $dab = Get-Command -Name 'dab' -ErrorAction SilentlyContinue
      $dotnetVersion = if ($null -ne $dotnet) { [string](& $dotnet.Source --version).Trim() } else { $null }
      $dabVersion = if ($null -ne $dab) { [string](& $dab.Source --version).Trim() } else { $null }

      [pscustomobject]@{
        DotnetAvailable = $null -ne $dotnet
        DotnetVersion = $dotnetVersion
        DabAvailable = $null -ne $dab
        DabPath = if ($null -ne $dab) { $dab.Source } else { $null }
        DabVersion = $dabVersion
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "DAB installation test failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed Data API Builder installation test.'
  }
}
