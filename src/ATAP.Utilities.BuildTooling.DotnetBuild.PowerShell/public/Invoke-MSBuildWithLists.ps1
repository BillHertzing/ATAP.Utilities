function Invoke-MSBuildWithLists {
  <#
  .SYNOPSIS
  Builds a project for each requested runtime, configuration, and target framework.

  .DESCRIPTION
  Invokes `dotnet build` for the Cartesian product of the supplied runtime targets,
  configurations, and target frameworks. Every producing invocation consumes the same
  validated artifacts context; independent OutputPath and BaseIntermediateOutputPath
  overrides are forbidden.

  .PARAMETER Path
  Project or solution path passed to `dotnet build`.

  .PARAMETER ArtifactsContext
  Resolver result containing Root, WorktreeId, ExecutionId, ArtifactsPath, BinlogPath,
  PackageStagingPath, and PublishStagingPath. Required for execution; omitted only for
  a non-producing WhatIf compatibility preview.

  .PARAMETER RuntimeTargetList
  Runtime identifiers to build.

  .PARAMETER TargetFrameworkList
  Target frameworks to build.

  .PARAMETER ConfigurationList
  Build configurations to build.

  .OUTPUTS
  PSCustomObject for each build combination.

  .EXAMPLE
  Invoke-MSBuildWithLists -Path '.\src\App\App.csproj' -ArtifactsContext $context -RuntimeTargetList 'win-x64' -TargetFrameworkList 'net10.0'

  .NOTES
  Paths and property values are passed to dotnet as discrete arguments.

  .LINK
  https://learn.microsoft.com/dotnet/core/tools/dotnet-build
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string] $Path = './',

    [Parameter()]
    [psobject] $ArtifactsContext,

    [ValidateNotNullOrEmpty()]
    [string[]] $RuntimeTargetList = @('win-x64', 'win-x86', 'linux-x64', 'linux-arm'),

    [ValidateNotNullOrEmpty()]
    [string[]] $TargetFrameworkList = @('net10.0'),

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

    $artifactArguments = @()
    if ($null -eq $ArtifactsContext) {
      if (-not $WhatIfPreference) {
        throw 'ArtifactsContext is required for a producing dotnet build invocation.'
      }
    } else {
      $required = @('Root', 'WorktreeId', 'ExecutionId', 'ArtifactsPath', 'BinlogPath', 'PackageStagingPath', 'PublishStagingPath')
      foreach ($name in $required) {
        if ($ArtifactsContext.PSObject.Properties.Name -notcontains $name -or [string]::IsNullOrWhiteSpace([string]$ArtifactsContext.$name)) {
          throw "ArtifactsContext.$name is required."
        }
      }
      $root = [IO.Path]::GetFullPath([string]$ArtifactsContext.Root)
      $artifactsPath = [IO.Path]::GetFullPath([string]$ArtifactsContext.ArtifactsPath)
      $expected = [IO.Path]::GetFullPath((Join-Path $root 'dotnet' 'ATAP.Utilities' ([string]$ArtifactsContext.WorktreeId) ([string]$ArtifactsContext.ExecutionId)))
      if (-not [IO.Path]::IsPathRooted($artifactsPath) -or $artifactsPath -cne $expected -or $artifactsPath -match '(?i)[\\/]Dropbox[\\/]') {
        throw "ArtifactsContext.ArtifactsPath '$artifactsPath' is not the canonical external path '$expected'."
      }
      $artifactArguments = @(
        '--artifacts-path'
        $artifactsPath
        "-p:ATAPArtifactsRoot=$root"
        "-p:ATAPArtifactsWorktreeId=$($ArtifactsContext.WorktreeId)"
        "-p:ATAPArtifactsExecutionId=$($ArtifactsContext.ExecutionId)"
      )
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
            $artifactArguments
            "-p:RuntimeIdentifier=$runtimeTarget"
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
              ArtifactsPath = if ($null -eq $ArtifactsContext) { $null } else { [string]$ArtifactsContext.ArtifactsPath }
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
            ArtifactsPath = [string]$ArtifactsContext.ArtifactsPath
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