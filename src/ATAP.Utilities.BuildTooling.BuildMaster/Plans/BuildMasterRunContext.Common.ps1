
<#
.SYNOPSIS
Shared helper functions for BuildMaster run-context plan scripts.

.DESCRIPTION
This file intentionally contains multiple helper functions (It is NOT eponymous to
  a single cmdlet). It is dot-sourced by the Initialize-* and Invoke-* plan scripts
In this folder to provide a single place for run-context directory layout,
retention sweeping, JSON shape, and tier-gate evaluation.

All public functions in this file follow the standard
CmdletBinding / BEGIN-PROCESS-END layout with $fn and $mn defined in BEGIN so the
Write-PSFMessage calls remain consistent with the wider repo convention.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
#>

Set-StrictMode -Version Latest

function Resolve-BuildMasterRunContextPath {
  <#
  .SYNOPSIS
    Computes the per-build run-context directory under _generated/buildmaster.
  .DESCRIPTION
    Sanitizes the supplied BuildMaster build id into a safe folder name and
    returns the fully-qualified path. Does NOT create the directory.
  .PARAMETER SourcePath
    Repository root or working directory under which _generated/buildmaster lives.
  .PARAMETER BuildMasterBuildId
    The BuildMaster build identifier (e.g. $BuildMasterId(build) in OtterScript).
  .OUTPUTS
    [string] Absolute path to the run-context directory for this build.
  .EXAMPLE
    Resolve-BuildMasterRunContextPath -SourcePath 'C:\src\Repo' -BuildMasterBuildId '12345'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    Initialize-BuildMasterRunContextDirectory
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$BuildMasterBuildId
  )

  begin {
    $fn = 'Resolve-BuildMasterRunContextPath'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  process {
    if ([string]::IsNullOrWhiteSpace($BuildMasterBuildId)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'BuildMasterBuildId is required.'
      throw 'BuildMasterBuildId is required. Pass $BuildMasterId(build) from the Otter plan.'
    }

    $safeBuildId = ($BuildMasterBuildId.Trim() -replace '[^A-Za-z0-9._-]', '-').Trim('.-_')
    if ([string]::IsNullOrWhiteSpace($safeBuildId)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "BuildMasterBuildId '$BuildMasterBuildId' cannot be converted to a folder name."
      throw "BuildMasterBuildId '$BuildMasterBuildId' cannot be converted to a run-context folder name."
    }

    $root = Join-Path -Path $SourcePath -ChildPath '_generated/buildmaster'
    return [System.IO.Path]::GetFullPath((Join-Path -Path $root -ChildPath $safeBuildId))
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Clear-OldBuildMasterRunContexts {
  <#
  .SYNOPSIS
    Deletes stale per-build run-context directories beyond a retention window.
  .DESCRIPTION
    Removes sibling run-context directories under _generated/buildmaster that are
    older than $RetentionDays and that do not belong to the currently-active build.
  .PARAMETER SourcePath
    Repository root containing _generated/buildmaster.
  .PARAMETER ActiveBuildMasterBuildId
    The build id whose directory must be preserved regardless of age.
  .PARAMETER RetentionDays
    Number of days a non-active run-context may live untouched before deletion.
  .OUTPUTS
    None. Side effect: removes directories.
  .EXAMPLE
    Clear-OldBuildMasterRunContexts -SourcePath 'C:\src\Repo' -ActiveBuildMasterBuildId '12345'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    Resolve-BuildMasterRunContextPath
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ActiveBuildMasterBuildId,

    [ValidateRange(0, 365)]
    [int]$RetentionDays = 14
  )

  begin {
    $fn = 'Clear-OldBuildMasterRunContexts'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (RetentionDays=$RetentionDays)"
  }

  process {
    if ($RetentionDays -lt 1) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'RetentionDays<1; skipping sweep.'
      return
    }

    $root = [System.IO.Path]::GetFullPath((Join-Path -Path $SourcePath -ChildPath '_generated/buildmaster'))
    if (-not (Test-Path -LiteralPath $root)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Root '$root' does not exist; nothing to sweep."
      return
    }

    $activePath = Resolve-BuildMasterRunContextPath -SourcePath $SourcePath -BuildMasterBuildId $ActiveBuildMasterBuildId
    $cutoff = [DateTime]::UtcNow.AddDays(-1 * $RetentionDays)

    try {
      Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { [System.IO.Path]::GetFullPath($_.FullName) -ne $activePath } |
        Where-Object { $_.LastWriteTimeUtc -lt $cutoff } |
        ForEach-Object {
          $staleContextPath = $_.FullName
          if ($PSCmdlet.ShouldProcess($staleContextPath, 'Remove stale BuildMaster run-context directory')) {
            try {
              Remove-Item -LiteralPath $staleContextPath -Recurse -Force -ErrorAction Stop
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Removed stale run-context '$staleContextPath'."
            } catch {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Skipped stale run-context '$staleContextPath' because it could not be removed. Exception: $($_.Exception.Message)"
            }
          }
        }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Skipped stale run-context sweep under '$root'. Exception: $($_.Exception.Message)"
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Sweep complete for '$root'."
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Initialize-BuildMasterRunContextDirectory {
  <#
  .SYNOPSIS
    Ensures the per-build run-context directory exists and prunes stale siblings.
  .DESCRIPTION
    Resolves the run-context path, creates the directory if absent, then triggers
    a retention sweep over peer build directories.
  .PARAMETER SourcePath
    Repository root containing _generated/buildmaster.
  .PARAMETER BuildMasterBuildId
    The BuildMaster build id whose context directory must be present.
  .PARAMETER RetentionDays
    Days of history kept for sibling build directories.
  .OUTPUTS
    [string] Absolute path of the run-context directory.
  .EXAMPLE
    Initialize-BuildMasterRunContextDirectory -SourcePath C:\src\Repo -BuildMasterBuildId 12345
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    Resolve-BuildMasterRunContextPath
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$BuildMasterBuildId,

    [ValidateRange(0, 365)]
    [int]$RetentionDays = 14
  )

  begin {
    $fn = 'Initialize-BuildMasterRunContextDirectory'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for build '$BuildMasterBuildId'"
  }

  process {
    $contextDirectory = Resolve-BuildMasterRunContextPath -SourcePath $SourcePath -BuildMasterBuildId $BuildMasterBuildId

    try {
      if ($PSCmdlet.ShouldProcess($contextDirectory, 'Create run-context directory')) {
        New-Item -ItemType Directory -Path $contextDirectory -Force | Out-Null
      }
      Clear-OldBuildMasterRunContexts -SourcePath $SourcePath -ActiveBuildMasterBuildId $BuildMasterBuildId -RetentionDays $RetentionDays
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to initialize run-context directory '$contextDirectory'. Exception: $($_.Exception.Message)"
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Run-context directory resolution complete: '$contextDirectory'."
    }

    return $contextDirectory
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-BuildMasterAllowDecisions {
  <#
  .SYNOPSIS
    Computes per-tier Allow* booleans against a configured ceiling tier.
  .DESCRIPTION
    Walks the canonical Experimental..Production tier list and asks the
    Test-PromotionWithinCeiling helper whether each tier is allowed.
  .PARAMETER CeilingTier
    The maximum allowed tier (inclusive). Tiers above this become $false.
  .OUTPUTS
    [System.Collections.IDictionary] Ordered hashtable keyed by tier name.
  .EXAMPLE
    Get-BuildMasterAllowDecisions -CeilingTier 'QA'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([System.Collections.IDictionary])]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
    [string]$CeilingTier
  )

  begin {
    $fn = 'Get-BuildMasterAllowDecisions'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (CeilingTier='$CeilingTier')"
  }

  process {
    $decisions = [ordered]@{}
    foreach ($tierName in @('Experimental', 'Development', 'Integration', 'QA', 'Production')) {
      $decisions[$tierName] = [bool](Test-PromotionWithinCeiling -CurrentTier $tierName -CeilingTier $CeilingTier -AsBoolean)
    }
    return $decisions
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Write-BuildMasterRunContextTextFile {
  <#
  .SYNOPSIS
    Writes a single text value to a run-context state file, creating parent directories.
  .DESCRIPTION
    Used by plan scripts to drop tier/version/allow markers that OtterScript can
    pick up with $FileContents().
  .PARAMETER Path
    Absolute or relative path of the file to write.
  .PARAMETER Value
    Value to write; $null is treated as empty string.
  .OUTPUTS
    None. Side effect: file is written.
  .EXAMPLE
    Write-BuildMasterRunContextTextFile -Path '_current_tier.tmp' -Value 'QA'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [AllowNull()]
    [object]$Value
  )

  begin {
    $fn = 'Write-BuildMasterRunContextTextFile'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Path='$Path')"
  }

  process {
    try {
      $directory = Split-Path -Parent $Path
      if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
      }
      [string]$text = if ($null -eq $Value) { '' } else { [string]$Value }
      if ($PSCmdlet.ShouldProcess($Path, 'Write run-context text file')) {
        Set-Content -LiteralPath $Path -Value $text -Encoding utf8 -NoNewline
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to write '$Path'. Exception: $($_.Exception.Message)"
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Write complete for '$Path'."
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function ConvertTo-BuildMasterRunContextHashtable {
  <#
  .SYNOPSIS
    Converts an arbitrary PSObject (or $null) to an ordered hashtable.
  .DESCRIPTION
    Helper used when merging the previous build-context.json into a new payload.
  .PARAMETER InputObject
    Source object whose top-level properties will become hashtable keys.
  .OUTPUTS
    [System.Collections.IDictionary] An ordered hashtable; empty for $null input.
  .EXAMPLE
    ConvertTo-BuildMasterRunContextHashtable -InputObject $existing
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([System.Collections.IDictionary])]
  param(
    [AllowNull()]
    [object]$InputObject
  )

  begin {
    $fn = 'ConvertTo-BuildMasterRunContextHashtable'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  process {
    $result = [ordered]@{}
    if ($null -eq $InputObject) {
      return $result
    }

    foreach ($property in $InputObject.PSObject.Properties) {
      $result[$property.Name] = $property.Value
    }
    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Read-BuildMasterRunContextJson {
  <#
  .SYNOPSIS
    Reads the prior build-context.json document from a run-context directory.
  .DESCRIPTION
    Returns $null if the file is absent; throws with a friendly message if it
    exists but cannot be parsed as JSON.
  .PARAMETER ContextDirectory
    Folder containing build-context.json.
  .OUTPUTS
    [PSCustomObject] or $null.
  .EXAMPLE
    Read-BuildMasterRunContextJson -ContextDirectory $contextDirectory
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ContextDirectory
  )

  begin {
    $fn = 'Read-BuildMasterRunContextJson'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (ContextDirectory='$ContextDirectory')"
  }

  process {
    $path = Join-Path -Path $ContextDirectory -ChildPath 'build-context.json'
    if (-not (Test-Path -LiteralPath $path)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No existing build-context.json at '$path'."
      return $null
    }

    try {
      return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Malformed BuildMaster run-context JSON at '$path'. Exception: $($_.Exception.Message)"
      throw "BuildMaster run context JSON is malformed at '$path': $($_.Exception.Message)"
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Read attempt complete for '$path'."
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Write-BuildMasterJsonFileAtomically {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
    [Parameter(Mandatory)][ValidateNotNull()][string]$Content,
    [ValidateRange(1, 20)][int]$MaxAttempts = 10,
    [ValidateRange(10, 5000)][int]$RetryDelayMilliseconds = 200
  )

  $temporaryPath = '{0}.{1}.{2}.tmp' -f $Path, $PID, [Guid]::NewGuid().ToString('N')
  try {
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
      try {
        [System.IO.File]::WriteAllText(
          $temporaryPath,
          $Content,
          [System.Text.UTF8Encoding]::new($false)
        )
        [System.IO.File]::Move($temporaryPath, $Path, $true)
        return
      } catch [System.IO.IOException] {
        if ($attempt -eq $MaxAttempts) { throw }
        Start-Sleep -Milliseconds ($RetryDelayMilliseconds * $attempt)
      }
    }
  } finally {
    if (Test-Path -LiteralPath $temporaryPath) {
      Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
  }
}

function Write-BuildMasterRunContextJson {
  <#
  .SYNOPSIS
    Writes (or merges into) the build-context.json document for the active build.
  .DESCRIPTION
    Enforces invariants across reruns: the same BuildMasterBuildId may not be
    re-tagged onto a different build, and a captured ResolvedVersion must not
    drift between stages.
  .PARAMETER ContextDirectory
    Folder containing build-context.json.
  .PARAMETER BuildMasterBuildId
    Build identifier captured into the document.
  .PARAMETER BuildNumber
    Optional BuildMaster build number string.
  .PARAMETER ExecutionId
    Optional BuildMaster execution identifier.
  .PARAMETER ApplicationName
    The product/application this build belongs to.
  .PARAMETER Branch
    Optional source-branch label.
  .PARAMETER SourcePath
    The working copy / repository root.
  .PARAMETER ProjectPath
    Path to the project being built.
  .PARAMETER CurrentTier
    Tier this stage is running at.
  .PARAMETER CeilingTier
    Maximum tier allowed for this build.
  .PARAMETER ResolvedVersion
    The immutable package version associated with this build id.
  .PARAMETER PrereleaseLabel
    Optional prerelease label component.
  .PARAMETER AllowDecisions
    Hashtable of per-tier allow booleans (typically from Get-BuildMasterAllowDecisions).
  .PARAMETER StateFiles
    Optional map of logical key -> filesystem path for tier-state markers.
  .PARAMETER AdditionalData
    Optional extra keys to merge into the payload (e.g. PipelineKind, PackageName).
  .PARAMETER RetentionDays
    Days of retention captured in the document for reference.
  .OUTPUTS
    [PSCustomObject] The complete payload that was persisted.
  .EXAMPLE
    Write-BuildMasterRunContextJson -ContextDirectory $dir -BuildMasterBuildId 1 ...
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ContextDirectory,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$BuildMasterBuildId,

    [AllowEmptyString()]
    [string]$BuildNumber,

    [AllowEmptyString()]
    [string]$ExecutionId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName,

    [AllowEmptyString()]
    [string]$Branch,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath,

    [AllowEmptyString()]
    [string]$ProjectPath,

    [Parameter(Mandatory)]
    [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
    [string]$CurrentTier,

    [Parameter(Mandatory)]
    [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
    [string]$CeilingTier,

    [AllowEmptyString()]
    [string]$ResolvedVersion,

    [AllowEmptyString()]
    [string]$PrereleaseLabel,

    [Parameter(Mandatory)]
    [System.Collections.IDictionary]$AllowDecisions,

    [AllowNull()]
    [System.Collections.IDictionary]$StateFiles = $null,

    [AllowNull()]
    [System.Collections.IDictionary]$AdditionalData = $null,

    [ValidateRange(0, 365)]
    [int]$RetentionDays = 14
  )

  begin {
    $fn = 'Write-BuildMasterRunContextJson'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn (BuildId='$BuildMasterBuildId'; Tier='$CurrentTier'; Ceiling='$CeilingTier')"
  }

  process {
    try {
      New-Item -ItemType Directory -Path $ContextDirectory -Force | Out-Null
      $existing = Read-BuildMasterRunContextJson -ContextDirectory $ContextDirectory

      if ($existing) {
        if ($existing.BuildMasterBuildId -and [string]$existing.BuildMasterBuildId -ne $BuildMasterBuildId) {
          throw "BuildMaster run context '$ContextDirectory' belongs to build id '$($existing.BuildMasterBuildId)', not '$BuildMasterBuildId'."
        }

        $existingResolved = [string]$existing.ResolvedVersion
        if (-not [string]::IsNullOrWhiteSpace($existingResolved) -and
          -not [string]::IsNullOrWhiteSpace($ResolvedVersion) -and
          $existingResolved -ne $ResolvedVersion) {
          throw "BuildMaster run context '$ContextDirectory' captured version '$existingResolved', but this run resolved '$ResolvedVersion'."
        }
      }

      $payload = ConvertTo-BuildMasterRunContextHashtable -InputObject $existing
      $payload['BuildMasterBuildId'] = $BuildMasterBuildId
      $payload['BuildNumber'] = $BuildNumber
      $payload['ExecutionId'] = $ExecutionId
      $payload['ApplicationName'] = $ApplicationName
      $payload['Branch'] = $Branch
      $payload['SourcePath'] = $SourcePath
      $payload['ProjectPath'] = $ProjectPath
      $payload['CurrentTier'] = $CurrentTier
      $payload['CeilingTier'] = $CeilingTier
      $payload['ResolvedVersion'] = $ResolvedVersion
      $payload['PrereleaseLabel'] = $PrereleaseLabel
      $payload['AllowDecisions'] = $AllowDecisions
      if ($null -ne $StateFiles -and $StateFiles.Count -gt 0) {
        $payload['StateFiles'] = $StateFiles
      } elseif (-not $payload.Contains('StateFiles')) {
        $payload['StateFiles'] = @{}
      }
      $payload['ContextDirectory'] = $ContextDirectory
      $payload['RetentionDays'] = $RetentionDays
      $payload['RetryPolicy'] = 'Refresh re-computable state; fail if an existing captured version conflicts.'
      $payload['StateContract'] = '_generated/buildmaster/<BuildMasterBuildId>/'
      $payload['TimestampUtc'] = [DateTime]::UtcNow.ToString('o')

      if ($null -ne $AdditionalData) {
        foreach ($key in $AdditionalData.Keys) {
          $payload[$key] = $AdditionalData[$key]
        }
      }

      $path = Join-Path -Path $ContextDirectory -ChildPath 'build-context.json'
      if ($PSCmdlet.ShouldProcess($path, 'Write build-context.json')) {
        $json = $payload | ConvertTo-Json -Depth 12
        Write-BuildMasterJsonFileAtomically -Path $path -Content $json
      }
      return [PSCustomObject]$payload
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed writing build-context.json in '$ContextDirectory'. Exception: $($_.Exception.Message)"
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Write attempt complete for '$ContextDirectory'."
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Write-BuildMasterRunStateFiles {
  <#
  .SYNOPSIS
    Writes every value in $Values to the matching path in $StateFiles.
  .DESCRIPTION
    Throws if $Values contains a key not present in the $StateFiles map; this
    catches typos in plan-script tier-state wiring early.
  .PARAMETER StateFiles
    Hashtable mapping logical key -> filesystem path.
  .PARAMETER Values
    Hashtable mapping logical key -> string value to write.
  .OUTPUTS
    None. Side effect: files are written via Write-BuildMasterRunContextTextFile.
  .EXAMPLE
    Write-BuildMasterRunStateFiles -StateFiles $map -Values @{ CurrentTier = 'QA' }
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory)]
    [System.Collections.IDictionary]$StateFiles,

    [Parameter(Mandatory)]
    [System.Collections.IDictionary]$Values
  )

  begin {
    $fn = 'Write-BuildMasterRunStateFiles'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn ($($Values.Keys.Count) values)"
  }

  process {
    foreach ($key in $Values.Keys) {
      if (-not $StateFiles.Contains($key)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "State file map does not define key '$key'."
        throw "State file map does not define key '$key'."
      }

      if ($PSCmdlet.ShouldProcess($StateFiles[$key], "Write state for '$key'")) {
        Write-BuildMasterRunContextTextFile -Path $StateFiles[$key] -Value $Values[$key]
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Initialize-LocalHostSettings {
  <#
  .SYNOPSIS
    Bootstraps $global:configRootKeys and $global:settings in a profileless shell context.
  .DESCRIPTION
    Loads the Set-GlobalConfigRootKeys and Get-HostSettings functions from the active
    source repository path, initializes default parameter values, and builds the
    settings hashtable for the current host name.
  .PARAMETER SourcePath
    The active repository base path containing the source tree.
  .PARAMETER IACBasePath
    Optional path to the IAC settings repository. Sourced dynamically if omitted.
  .OUTPUTS
    None. Side effect: populates $global:settings and $global:configRootKeys.
  .EXAMPLE
    Initialize-LocalHostSettings -SourcePath 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath,

    [string]$IACBasePath = ''
  )

  begin {
    $fn = 'Initialize-LocalHostSettings'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (SourcePath='$SourcePath')"
  }

  process {
    $hostName = ([System.Net.DNS]::GetHostByName($Null)).Hostname

    # 1. Establish PSDefaultParameterValues encoding and settings hooks
    if ($null -eq $global:PSDefaultParameterValues) {
      $global:PSDefaultParameterValues = @{}
    }
    $global:PSDefaultParameterValues['*:Encoding'] = 'UTF8'
    $global:PSDefaultParameterValues['*:Settings'] = { $global:settings }

    # 2. Load and run Set-GlobalConfigRootKeys
    if (-not (Get-Command -Name 'Set-GlobalConfigRootKeys' -CommandType Function -ErrorAction SilentlyContinue)) {
      $configRootKeysScript = Join-Path $SourcePath 'src\ATAP.Utilities.ConfigRootKeys.Powershell\public\Set-GlobalConfigRootKeys.ps1'
      if (Test-Path -LiteralPath $configRootKeysScript -PathType Leaf) {
        . $configRootKeysScript
      } else {
        Import-Module -Name 'ATAP.Utilities.ConfigRootKeys.PowerShell' -ErrorAction Stop
      }
    }
    Set-GlobalConfigRootKeys

    # 3. Load and run Get-HostSettings
    if (-not (Get-Command -Name 'Get-HostSettings' -CommandType Function -ErrorAction SilentlyContinue)) {
      $hostSettingsScript = Join-Path $SourcePath 'src\ATAP.Utilities.Powershell\public\Get-HostSettings.ps1'
      if (Test-Path -LiteralPath $hostSettingsScript -PathType Leaf) {
        . $hostSettingsScript
      } else {
        Import-Module -Name 'ATAP.Utilities.PowerShell' -ErrorAction Stop
      }
    }

    # 4. Populate the settings hashtable
    $global:settings = Get-HostSettings -hostName $hostName -IACBasePath $IACBasePath

    # 5. Populate machine-runtime entries just like the machine profile does
    $global:settings[$global:configRootKeys['IsElevatedConfigRootKey']] = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    $inheritedEnvironment = [System.Environment]::GetEnvironmentVariable('Environment')
    $inProcessEnvironment = if ($inheritedEnvironment) { $inheritedEnvironment } else { 'Production' }
    $global:settings[$global:configRootKeys['ENVIRONMENTConfigRootKey']] = $inProcessEnvironment

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Local host settings initialized successfully via standalone loader."
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}
