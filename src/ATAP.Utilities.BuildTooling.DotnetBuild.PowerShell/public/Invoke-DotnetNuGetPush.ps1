#Requires -Version 7.0

function Invoke-DotnetNuGetPush {
  <#
  .SYNOPSIS
  Pushes one immutable NuGet package with the dotnet CLI.

  .DESCRIPTION
  Invokes `dotnet nuget push --skip-duplicate` using discrete arguments and
  returns the exit code and captured output. The API key is never logged.

  .PARAMETER NupkgPath
  NuGet package path.

  .PARAMETER FeedUri
  Destination NuGet feed URI.

  .PARAMETER ApiKey
  API key passed directly to dotnet.

  .OUTPUTS
  PSCustomObject with ExitCode, StdOut, and WhatIf.

  .EXAMPLE
  Invoke-DotnetNuGetPush -NupkgPath '.\package.nupkg' -FeedUri 'https://feed.example/v3/index.json' -ApiKey $key

  .NOTES
  The caller owns SecretName resolution; this leaf accepts only the resolved
  value and does not persist it.

  .LINK
  https://learn.microsoft.com/dotnet/core/tools/dotnet-nuget-push
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $NupkgPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $FeedUri,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ApiKey
  )

  begin {
    $fn = 'Invoke-DotnetNuGetPush'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    $arguments = @(
      'nuget', 'push', $NupkgPath,
      '--source', $FeedUri,
      '--api-key', $ApiKey,
      '--skip-duplicate'
    )

    if (-not $PSCmdlet.ShouldProcess($NupkgPath, "dotnet nuget push to $FeedUri")) {
      return [PSCustomObject]@{
        ExitCode = 0
        StdOut = ''
        WhatIf = $true
      }
    }

    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling dotnet nuget push '$NupkgPath' --source '$FeedUri' --api-key '***' --skip-duplicate" -Tag 'InvokeCommandCall'
      $stdout = @(& dotnet @arguments 2>&1)
      $exitCode = $LASTEXITCODE
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from dotnet nuget push with exit code $exitCode" -Tag 'InvokeCommandCall'
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "dotnet nuget push threw for '$NupkgPath'. Exception: $($_.Exception.Message)"
      throw
    }

    [PSCustomObject]@{
      ExitCode = $exitCode
      StdOut = ($stdout -join [Environment]::NewLine)
      WhatIf = $false
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
