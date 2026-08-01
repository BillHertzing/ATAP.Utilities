function Install-DabGlobalTool {
  <#
  .SYNOPSIS
  Installs or updates Microsoft.DataApiBuilder as a user-global .NET tool.

  .DESCRIPTION
  Installs DAB when absent and updates an existing installation otherwise. The caller
  may pin a version for host parity.

  .PARAMETER Version
  Optional Data API Builder version to install or update to.

  .OUTPUTS
  PSCustomObject.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [string] $Version
  )

  begin {
    $fn = 'Install-DabGlobalTool'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Preparing Data API Builder global-tool installation.'
  }

  process {
    try {
      $dotnet = Get-Command -Name 'dotnet' -ErrorAction Stop
      $dab = Get-Command -Name 'dab' -ErrorAction SilentlyContinue
      $verb = if ($null -eq $dab) { 'install' } else { 'update' }
      $arguments = @('tool', $verb, '--global', 'Microsoft.DataApiBuilder')
      if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $arguments += @('--version', $Version)
      }

      if (-not $PSCmdlet.ShouldProcess('Microsoft.DataApiBuilder', "dotnet tool $verb --global")) {
        return [pscustomobject]@{ Action = $verb; WhatIf = $true; Version = $Version; ExitCode = 0 }
      }

      $result = Invoke-DabCommand -DabPath $dotnet.Source -ArgumentList $arguments
      $installed = Test-DabInstallation
      [pscustomobject]@{
        Action = $verb
        WhatIf = $false
        RequestedVersion = $Version
        DabVersion = $installed.DabVersion
        ExitCode = $result.ExitCode
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "DAB global-tool installation failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed Data API Builder global-tool installation.'
  }
}
