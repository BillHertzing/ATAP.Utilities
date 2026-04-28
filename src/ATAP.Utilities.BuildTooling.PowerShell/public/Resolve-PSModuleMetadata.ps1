<#
.SYNOPSIS
Resolves metadata for a PowerShell module located at a given start path.

.DESCRIPTION
Discovers the single .psd1 manifest file in the module folder (matching the
folder's base name), resolves the repository root via
'git -C <path> rev-parse --show-toplevel', and returns a PSCustomObject with
ModuleName, ModuleRoot, RepoRoot, ManifestPath, and OutputRoot. OutputRoot is
always built as '<RepoRoot>/_generated/psmodules/<ModuleName>/' and is NOT
created by this cmdlet — it is strictly read-only.

Throws a clear, actionable error if zero or more than one matching manifest is
found, or if the git rev-parse call fails.

.PARAMETER StartPath
The folder that represents the module root. Defaults to $PSScriptRoot. Must
contain exactly one '*.psd1' whose BaseName matches the folder name.

.OUTPUTS
[PSCustomObject] with fields:
  - ModuleName     : The manifest's BaseName (also the folder name).
  - ModuleRoot     : Absolute, normalized path to the module folder.
  - RepoRoot       : Absolute, normalized path to the git repository root.
  - ManifestPath   : Absolute, normalized path to the .psd1 manifest.
  - OutputRoot     : '<RepoRoot>/_generated/psmodules/<ModuleName>/'.

.EXAMPLE
$meta = Resolve-PSModuleMetadata -StartPath 'C:/repo/src/ATAP.Utilities.BuildTooling.PowerShell'

Returns the metadata PSCustomObject for the module at that path.

.EXAMPLE
$meta = Resolve-PSModuleMetadata

Resolves metadata using $PSScriptRoot as the start path (typical usage from
inside a module's module.build.ps1 file).

.NOTES
AI assisted using Powershell.instructions.md as guidelines

This cmdlet is strictly read-only: it does not create, modify, or delete any
files. Tier: T1 (Phase 1, task T-10).
#>
function Resolve-PSModuleMetadata {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false)]
    [string]$StartPath = $PSScriptRoot
  )

  begin {
    $fn = 'Resolve-PSModuleMetadata'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    # Check and populate simple parameter: StartPath
    if ([string]::IsNullOrWhiteSpace($StartPath)) {
      $msg = "Parameter 'StartPath' is null or empty and no default was available (is this being called outside a script file?)."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with StartPath='$StartPath'" -Tag 'Trace'
  }

  process {
    if (-not (Test-Path -LiteralPath $StartPath -PathType Container)) {
      $msg = "StartPath does not exist or is not a directory: '$StartPath'"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    # Normalize StartPath to an absolute path with forward-slash separators.
    $resolvedStart = (Resolve-Path -LiteralPath $StartPath).ProviderPath
    $moduleRoot = $resolvedStart -replace '\\', '/'
    $moduleRoot = $moduleRoot.TrimEnd('/')

    $folderName = Split-Path -Path $moduleRoot -Leaf
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Looking for '<folder>.psd1' where folder='$folderName' in '$moduleRoot'"

    # Find all .psd1 files directly in $moduleRoot (non-recursive).
    $allPsd1 = @(Get-ChildItem -LiteralPath $moduleRoot -Filter '*.psd1' -File -ErrorAction SilentlyContinue)
    $matchingPsd1 = @($allPsd1 | Where-Object { $_.BaseName -eq $folderName })

    if ($matchingPsd1.Count -eq 0) {
      $msg = "No '*.psd1' manifest with BaseName '$folderName' was found in '$moduleRoot'. A module folder must contain exactly one manifest whose BaseName matches the folder name."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    if ($matchingPsd1.Count -gt 1) {
      $paths = ($matchingPsd1 | ForEach-Object { $_.FullName }) -join '; '
      $msg = "Multiple '*.psd1' manifests with BaseName '$folderName' were found in '$moduleRoot': $paths. A module folder must contain exactly one matching manifest."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $manifest = $matchingPsd1[0]
    $manifestPath = ($manifest.FullName -replace '\\', '/')
    $moduleName = $manifest.BaseName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Matched manifest '$manifestPath' (ModuleName='$moduleName')"

    # Resolve repo root via git. Use '-C <path>' to avoid changing the caller's CWD.
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling 'git -C `"$moduleRoot`" rev-parse --show-toplevel'" -Tag 'InvokeCommandCall'
    $gitOutput = & git -C $moduleRoot rev-parse --show-toplevel 2>&1
    $gitExit = $LASTEXITCODE
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from 'git -C `"$moduleRoot`" rev-parse --show-toplevel' (ExitCode=$gitExit)" -Tag 'InvokeCommandCall'

    if ($gitExit -ne 0 -or [string]::IsNullOrWhiteSpace([string]$gitOutput)) {
      $msg = "Unable to resolve the repository root via 'git -C `"$moduleRoot`" rev-parse --show-toplevel'. Exit code: $gitExit. Output: $gitOutput"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $repoRoot = ([string]$gitOutput).Trim() -replace '\\', '/'
    $repoRoot = $repoRoot.TrimEnd('/')

    $outputRoot = "$repoRoot/_generated/psmodules/$moduleName/"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Resolved module '$moduleName' at '$moduleRoot'; RepoRoot='$repoRoot'; OutputRoot='$outputRoot'"

    [PSCustomObject]@{
      ModuleName   = $moduleName
      ModuleRoot   = $moduleRoot
      RepoRoot     = $repoRoot
      ManifestPath = $manifestPath
      OutputRoot   = $outputRoot
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
