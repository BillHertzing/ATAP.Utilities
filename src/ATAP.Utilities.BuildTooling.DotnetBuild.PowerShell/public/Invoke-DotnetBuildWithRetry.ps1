function Invoke-DotnetBuildWithRetry {
  <#
  .SYNOPSIS
  Restores and builds with bounded retry and marker-owned external artifact recovery.

  .DESCRIPTION
  Runs restore followed by build for each project/configuration. Every dotnet producer
  receives the same validated ArtifactsContext. Zero-byte reference and tmp-webcil
  recovery is inspected only beneath that external execution path; this function never
  scans or removes an in-worktree obj directory.

  .PARAMETER SolutionOrProjectPath
  One or more solution or project paths.

  .PARAMETER ArtifactsContext
  Resolver result containing Root, WorktreeId, ExecutionId, ArtifactsPath, BinlogPath,
  PackageStagingPath, and PublishStagingPath. The owner marker must match this run.

  .PARAMETER Configuration
  Build configurations. Defaults to Debug.

  .PARAMETER MaxRetries
  HTTP-cache retry count for NU1101/NU1202 restore failures.

  .PARAMETER BuildLogPath
  Optional explicit binlog path. Otherwise a project/configuration-specific path is
  derived beneath the context BinlogPath directory.

  .OUTPUTS
  PSCustomObject per project/configuration.

  .EXAMPLE
  Invoke-DotnetBuildWithRetry -SolutionOrProjectPath '.\ATAP.Utilities.sln' -ArtifactsContext $context

  .NOTES
  HTTP-cache clearing is retained only for the established NU1101/NU1202 retry path.
  No global-packages deletion or in-tree artifact deletion is performed.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [object[]] $SolutionOrProjectPath,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [psobject] $ArtifactsContext,

    [ValidateSet('Debug', 'ReleaseWithTrace', 'Release')]
    [string[]] $Configuration = @('Debug'),

    [ValidateRange(0, 10)]
    [int] $MaxRetries = 1,

    [Alias('bl')]
    [string] $BuildLogPath
  )

  begin {
    $fn = 'Invoke-DotnetBuildWithRetry'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if (-not (Get-Command -Name 'dotnet' -ErrorAction SilentlyContinue)) {
      throw 'dotnet was not found on PATH.'
    }

    foreach ($name in @('Root', 'WorktreeId', 'ExecutionId', 'ArtifactsPath', 'BinlogPath', 'PackageStagingPath', 'PublishStagingPath')) {
      if ($ArtifactsContext.PSObject.Properties.Name -notcontains $name -or [string]::IsNullOrWhiteSpace([string]$ArtifactsContext.$name)) {
        throw "ArtifactsContext.$name is required."
      }
    }

    $artifactsRoot = [IO.Path]::GetFullPath([string]$ArtifactsContext.Root)
    $artifactsPath = [IO.Path]::GetFullPath([string]$ArtifactsContext.ArtifactsPath)
    $expectedArtifactsPath = [IO.Path]::GetFullPath((Join-Path $artifactsRoot 'dotnet' 'ATAP.Utilities' ([string]$ArtifactsContext.WorktreeId) ([string]$ArtifactsContext.ExecutionId)))
    if (-not [IO.Path]::IsPathRooted($artifactsPath) -or $artifactsPath -cne $expectedArtifactsPath -or $artifactsPath -match '(?i)[\\/]Dropbox[\\/]') {
      throw "ArtifactsContext.ArtifactsPath '$artifactsPath' is not the canonical external path '$expectedArtifactsPath'."
    }

    $artifactsOwner = "ATAP.Utilities|$($ArtifactsContext.WorktreeId)|$($ArtifactsContext.ExecutionId)"
    $ownerMarkerPath = Join-Path $artifactsPath '.atap-artifacts-owner'
    [IO.Directory]::CreateDirectory($artifactsPath) | Out-Null
    if (Test-Path -LiteralPath $ownerMarkerPath -PathType Leaf) {
      $existingOwner = ([IO.File]::ReadAllText($ownerMarkerPath)).Trim()
      if ($existingOwner -cne $artifactsOwner) {
        throw "ArtifactsPath '$artifactsPath' is owned by '$existingOwner', not '$artifactsOwner'."
      }
    } else {
      try {
        $stream = [IO.FileStream]::new($ownerMarkerPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        try {
          $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
          try { $writer.Write($artifactsOwner) } finally { $writer.Dispose() }
        } finally { $stream.Dispose() }
      } catch [IO.IOException] {
        $existingOwner = ([IO.File]::ReadAllText($ownerMarkerPath)).Trim()
        if ($existingOwner -cne $artifactsOwner) { throw }
      }
    }

    $artifactArguments = @(
      '--artifacts-path'
      $artifactsPath
      "-p:ATAPArtifactsRoot=$artifactsRoot"
      "-p:ATAPArtifactsWorktreeId=$($ArtifactsContext.WorktreeId)"
      "-p:ATAPArtifactsExecutionId=$($ArtifactsContext.ExecutionId)"
    )
    $nuGetNotFoundPattern = 'NU1101|NU1202'
    $fodyLockPattern = 'Fody.*IOException|cannot access the file.*\.pdb.*being used by another process|Access to the path.*[Ff]ody.*is denied'
    $webcilLockPattern = 'tmp-webcil|Cannot access.*\.webcil|Access to the path.*tmp-webcil.*is denied|being used by another process.*tmp-webcil'

    function Find-ZeroByteRefAssemblies {
      param([Parameter(Mandatory)][string] $RootPath)
      @(Get-ChildItem -LiteralPath $RootPath -Recurse -Filter '*.dll' -File -ErrorAction SilentlyContinue |
          Where-Object { $_.Length -eq 0 -and [IO.Path]::GetFileName($_.DirectoryName) -eq 'ref' })
    }

    function Remove-MarkerOwnedWebcilDirectories {
      param([Parameter(Mandatory)][string] $RootPath)
      $currentOwner = if (Test-Path -LiteralPath $ownerMarkerPath -PathType Leaf) { ([IO.File]::ReadAllText($ownerMarkerPath)).Trim() } else { '' }
      if ($currentOwner -cne $artifactsOwner) {
        throw "Recovery refused because owner marker '$ownerMarkerPath' does not match '$artifactsOwner'."
      }
      $directories = @(Get-ChildItem -LiteralPath $RootPath -Filter 'tmp-webcil' -Recurse -Directory -ErrorAction SilentlyContinue)
      $allRemoved = $directories.Count -gt 0
      foreach ($directory in $directories) {
        $candidate = [IO.Path]::GetFullPath($directory.FullName)
        if (-not $candidate.StartsWith($artifactsPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
          throw "Recovery refused for path outside the current ArtifactsPath: '$candidate'."
        }
        if ($PSCmdlet.ShouldProcess($candidate, 'Remove marker-owned tmp-webcil directory')) {
          try { Remove-Item -LiteralPath $candidate -Recurse -Force -ErrorAction Stop }
          catch {
            $allRemoved = $false
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Could not remove marker-owned '$candidate': $($_.Exception.Message)"
          }
        }
      }
      $allRemoved
    }
  }

  process {
    $resolvedPaths = @($SolutionOrProjectPath | ForEach-Object {
        $raw = if ($_ -is [IO.FileSystemInfo]) { $_.FullName } else { [string]$_ }
        [IO.Path]::GetFullPath($raw, $PWD.ProviderPath)
      })

    foreach ($currentPath in $resolvedPaths) {
      if (-not (Test-Path -LiteralPath $currentPath)) { throw "Build path was not found: $currentPath" }
      foreach ($innerConfiguration in @($Configuration)) {
        $projectName = [IO.Path]::GetFileNameWithoutExtension($currentPath)
        $resolvedBuildLogPath = if ($BuildLogPath) {
          [IO.Path]::GetFullPath($BuildLogPath, $PWD.ProviderPath)
        } else {
          $logRoot = Split-Path -Parent ([string]$ArtifactsContext.BinlogPath)
          Join-Path $logRoot $projectName $innerConfiguration "$projectName.binlog"
        }
        [IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedBuildLogPath)) | Out-Null
        $restoreArguments = @('restore', $currentPath) + $artifactArguments
        $buildArguments = @('build', $currentPath, '-c', $innerConfiguration, '--no-restore') + $artifactArguments + @("/bl:$resolvedBuildLogPath")
        $result = [ordered]@{
          ExitCode = -1
          RestoreOutput = @()
          BuildOutput = @()
          RetryCount = 0
          ArtifactsPath = $artifactsPath
          OwnerMarkerPath = $ownerMarkerPath
          RestoreArguments = $restoreArguments
          BuildArguments = $buildArguments
          WhatIf = [bool]$WhatIfPreference
        }

        if (-not $PSCmdlet.ShouldProcess("$currentPath [$innerConfiguration]", 'dotnet restore and build')) {
          $result.ExitCode = 0
          [pscustomobject]$result
          continue
        }

        $restoreSuccess = $false
        $restoreTerminalFailure = $false
        for ($retryCount = 0; $retryCount -le $MaxRetries -and -not $restoreSuccess; $retryCount++) {
          if ($retryCount -gt 0) {
            if ($PSCmdlet.ShouldProcess('NuGet HTTP cache', 'Clear http-cache for bounded restore retry')) {
              & dotnet nuget locals http-cache --clear 2>&1 | Out-Null
            }
          }
          $restoreOutput = @(& dotnet @restoreArguments 2>&1)
          $restoreExitCode = $LASTEXITCODE
          $result.RestoreOutput = $restoreOutput
          $result.RetryCount = $retryCount
          if ($restoreExitCode -eq 0) { $restoreSuccess = $true; break }
          $restoreText = $restoreOutput -join "`n"
          if ($restoreText -match $fodyLockPattern) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Restore failed on a Fody lock; restart the C# language server. Global-packages deletion is forbidden.'
            $result.ExitCode = $restoreExitCode
            $restoreTerminalFailure = $true
            break
          }
          if ($restoreText -notmatch $nuGetNotFoundPattern -or $retryCount -ge $MaxRetries) {
            $result.ExitCode = $restoreExitCode
            $restoreTerminalFailure = $true
            break
          }
        }
        if ($restoreTerminalFailure -or -not $restoreSuccess) {
          [pscustomobject]$result
          continue
        }

        $zeroByteRefs = Find-ZeroByteRefAssemblies -RootPath $artifactsPath
        if ($zeroByteRefs.Count -gt 0) {
          $rebuildArguments = @('build', $currentPath, '-t:Rebuild', '-c', $innerConfiguration, '--no-restore') + $artifactArguments + @("/bl:$resolvedBuildLogPath")
          $rebuildOutput = @(& dotnet @rebuildArguments 2>&1)
          if ($LASTEXITCODE -ne 0) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Rebuild failed. Recovery is limited to marker-owned ArtifactsPath '$artifactsPath'; no in-tree obj deletion is permitted."
            $result.ExitCode = $LASTEXITCODE
            $result.BuildOutput = $rebuildOutput
            [pscustomobject]$result
            continue
          }
        }

        $buildOutput = @(& dotnet @buildArguments 2>&1)
        $buildExitCode = $LASTEXITCODE
        $result.BuildOutput = $buildOutput
        $result.ExitCode = $buildExitCode
        if ($buildExitCode -ne 0 -and ($buildOutput -join "`n") -match $webcilLockPattern) {
          [void](Remove-MarkerOwnedWebcilDirectories -RootPath $artifactsPath)
        }
        [pscustomobject]$result
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}