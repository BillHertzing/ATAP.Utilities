function Invoke-MSBuildWithLists {
  <#
  .SYNOPSIS
  Builds a project for each requested runtime, configuration, and target framework.

  .DESCRIPTION
  Invokes `dotnet build` directly for the Cartesian product of the supplied
  runtime targets, configurations, and target frameworks. Each result records
  the arguments, captured output, and exit code. No command text is evaluated.

  .PARAMETER Path
  Project or solution path passed to `dotnet build`.

  .PARAMETER OutputPath
  Output path passed as the `OutputPath` MSBuild property.

  .PARAMETER BaseIntermediateOutputPath
  Intermediate path passed as the `BaseIntermediateOutputPath` property.

  .PARAMETER RuntimeTargetList
  Runtime identifiers to build.

  .PARAMETER TargetFrameworkList
  Target frameworks to build.

  .PARAMETER ConfigurationList
  Build configurations to build.

  .OUTPUTS
  PSCustomObject for each build combination.

  .EXAMPLE
  Invoke-MSBuildWithLists -Path '.\src\App\App.csproj' -RuntimeTargetList 'win-x64' -TargetFrameworkList 'net8.0'

  .NOTES
  This implementation deliberately avoids Invoke-Expression so paths and
  property values are passed to dotnet as discrete arguments.

  .LINK
  https://learn.microsoft.com/dotnet/core/tools/dotnet-build
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string] $Path = './',

    [ValidateNotNullOrEmpty()]
    [string] $OutputPath = './bin',

    [ValidateNotNullOrEmpty()]
    [string] $BaseIntermediateOutputPath = './obj',

    [ValidateNotNullOrEmpty()]
    [string[]] $RuntimeTargetList = @('win-x64', 'win-x86', 'linux-x64', 'linux-arm'),

    [ValidateNotNullOrEmpty()]
    [string[]] $TargetFrameworkList = @('net8.0'),

    [ValidateNotNullOrEmpty()]
    [string[]] $ConfigurationList = @('Debug', 'Release')
  )

  begin {
    $fn = 'Invoke-MSBuildWithLists'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if (-not (Get-Command -Name 'dotnet' -ErrorAction SilentlyContinue)) {
      throw 'dotnet was not found on PATH.'
    }
  }

  process {
    if (-not (Test-Path -LiteralPath $Path)) {
      throw "Build path was not found: $Path"
    }

    foreach ($runtimeTarget in $RuntimeTargetList) {
      foreach ($configuration in $ConfigurationList) {
        foreach ($targetFramework in $TargetFrameworkList) {
          $arguments = @(
            'build'
            $Path
            "-p:OutputPath=$OutputPath"
            "-p:BaseIntermediateOutputPath=$BaseIntermediateOutputPath"
            "-p:RuntimeTarget=$runtimeTarget"
            "-p:Configuration=$configuration"
            "-p:TargetFramework=$targetFramework"
          )
          $target = "$Path [$runtimeTarget/$configuration/$targetFramework]"
          if (-not $PSCmdlet.ShouldProcess($target, 'dotnet build')) {
            [PSCustomObject]@{
              Path = $Path
              RuntimeTarget = $runtimeTarget
              Configuration = $configuration
              TargetFramework = $targetFramework
              Arguments = $arguments
              Output = @()
              ExitCode = 0
              WhatIf = $true
            }
            continue
          }

          try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling dotnet $($arguments -join ' ')" -Tag 'InvokeCommandCall'
            $output = @(& dotnet @arguments 2>&1)
            $exitCode = $LASTEXITCODE
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from dotnet build with exit code $exitCode" -Tag 'InvokeCommandCall'
          } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "dotnet build threw for '$target'. Exception: $($_.Exception.Message)"
            throw
          }

          [PSCustomObject]@{
            Path = $Path
            RuntimeTarget = $runtimeTarget
            Configuration = $configuration
            TargetFramework = $targetFramework
            Arguments = $arguments
            Output = $output
            ExitCode = $exitCode
            WhatIf = $false
          }
        }
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
