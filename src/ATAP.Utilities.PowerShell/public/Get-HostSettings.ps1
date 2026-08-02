<#
.SYNOPSIS
Builds the per-host settings hashtable for the named host.

.DESCRIPTION
Resolves the ATAP.IAC HostSettings.ps1 file, validates that
$global:configRootKeys has already been populated, loads the local helper needed
by the IAC fragments, then dot-sources HostSettings.ps1 in a child scope.

The IAC file defines its own Get-HostSettings function. This wrapper invokes
that inner function and returns the resulting hashtable whose keys are the
values from $global:configRootKeys.

Before returning, the wrapper also normalizes the reviewed
`BuildMasterApplicationByModule` map used by local BuildTooling cmdlets. This
keeps core ATAP PowerShell modules, including
`ATAP.Utilities.RulesManagement.PowerShell`, routed to the shared
`ATAP.Utilities-PowerShell` BuildMaster application even when an upstream
HostSettings fragment lags a newly-added module.

.PARAMETER hostName
Hostname used by the IAC HostSettings.ps1 dispatch switch.

.PARAMETER IACBasePath
Optional root of the ATAP.IAC repository or worktree. When omitted, the probe order is, most
specific first: `$env:ATAP_IAC_BASE_PATH` (process then user scope), the current sprint's ATAP.IAC
worktree, the stable ATAP.IAC checkout, and finally the copy shipped inside the installed
ATAP.Utilities.PowerShell module. See Get-IACHostSettingsCandidatePath.

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
$global:settings = Get-HostSettings -hostName $env:COMPUTERNAME

.NOTES
Requires $global:configRootKeys to be populated first. Call
Set-GlobalConfigRootKeys before this cmdlet.

The sprint worktree is discovered by pattern, never named. Until SC-0252 was fixed this function
hard-coded `ATAP.IAC-wt-9-Sprint-0007-work-items` as its only sprint-shaped candidate. That folder
disappeared at the end of Sprint 0007, so resolution silently fell through to the stable checkout
and every HostSettings edit made in a sprint worktree -- which is where the repository's boundary
rule says sprint work belongs -- had no runtime effect for four sprints.

Update-BuildMasterApplicationMap is a BACKSTOP, not the source of truth. It merges a small reviewed
set of module->application mappings so a lagging HostSettings fragment cannot break core module
routing. If a module you expect is missing from the effective map, fix the ATAP.IAC fragment; do not
add it here.
#>
function Get-HostSettings {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([hashtable])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $hostName,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [string] $IACBasePath
  )

  begin {
    $fn = 'Get-HostSettings'
    $mn = 'ATAP.Utilities.PowerShell'

    function Write-HostSettingsMessage {
      param(
        [Parameter(Mandatory = $true)]
        [string] $Level,

        [Parameter(Mandatory = $true)]
        [string] $Message
      )

      if (Get-Command -Name 'Write-PSFMessage' -CommandType Function, Cmdlet -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level $Level -Message $Message
        return
      }

      switch ($Level) {
        'Debug' { Write-Debug -Message $Message }
        'Verbose' { Write-Verbose -Message $Message }
        'Error' { Write-Error -Message $Message }
        default { Write-Verbose -Message $Message }
      }
    }

    function Add-CandidatePath {
      param(
        [System.Collections.Generic.List[string]] $CandidatePaths,
        [string] $Path
      )

      if ([string]::IsNullOrWhiteSpace($Path)) {
        return
      }

      if (-not $CandidatePaths.Contains($Path)) {
        [void] $CandidatePaths.Add($Path)
      }
    }

    function Update-BuildMasterApplicationMap {
      param(
        [Parameter(Mandatory = $true)]
        [hashtable] $SettingsHash
      )

      $settingsKey = $global:configRootKeys['BuildMasterApplicationByModuleConfigRootKey']
      if ([string]::IsNullOrWhiteSpace([string] $settingsKey)) {
        return
      }

      $requiredMappings = [ordered]@{
        'ATAP.Utilities.PowerShell'                    = 'ATAP.Utilities-PowerShell'
        'ATAP.Utilities.ConfigRootKeys.PowerShell'     = 'ATAP.Utilities-PowerShell'
        'ATAP.Utilities.BuildTooling.PowerShell'       = 'ATAP.Utilities-PowerShell'
        'ATAP.Utilities.DatabaseManagement.PowerShell' = 'ATAP.Utilities-PowerShell'
        'ATAP.Utilities.RulesManagement.PowerShell'    = 'ATAP.Utilities-PowerShell'
      }

      $resolvedMappings = @{}
      $existingMappings = $SettingsHash[$settingsKey]
      if ($null -ne $existingMappings) {
        if (-not ($existingMappings -is [System.Collections.IDictionary])) {
          throw "The '$settingsKey' setting must be a hashtable/dictionary when present. Found '$($existingMappings.GetType().FullName)'."
        }

        foreach ($key in $existingMappings.Keys) {
          $resolvedMappings[[string] $key] = [string] $existingMappings[$key]
        }
      }

      $addedModules = [System.Collections.Generic.List[string]]::new()
      foreach ($moduleName in $requiredMappings.Keys) {
        $expectedApplication = $requiredMappings[$moduleName]
        if ($resolvedMappings.ContainsKey($moduleName)) {
          $currentApplication = [string] $resolvedMappings[$moduleName]
          if ([string]::IsNullOrWhiteSpace($currentApplication)) {
            $resolvedMappings[$moduleName] = $expectedApplication
            [void] $addedModules.Add($moduleName)
            continue
          }

          if ($currentApplication -ne $expectedApplication) {
            throw "Reviewed BuildMaster mapping conflict for module '$moduleName'. Expected '$expectedApplication' but HostSettings returned '$currentApplication'."
          }

          continue
        }

        $resolvedMappings[$moduleName] = $expectedApplication
        [void] $addedModules.Add($moduleName)
      }

      $SettingsHash[$settingsKey] = $resolvedMappings
      if ($addedModules.Count -gt 0) {
        Write-HostSettingsMessage -Level Verbose -Message "Normalized BuildMaster module routing by adding reviewed mapping(s) for: $($addedModules -join ', ')."
      }
    }


    Write-HostSettingsMessage -Level Debug -Message "Entering $fn for hostName '$hostName'"

    if ($null -eq $global:configRootKeys -or
      -not ($global:configRootKeys -is [hashtable]) -or
      $global:configRootKeys.Count -eq 0) {
      $errorMessage = '$global:configRootKeys is not populated. Call Set-GlobalConfigRootKeys before Get-HostSettings.'
      Write-HostSettingsMessage -Level Error -Message $errorMessage
      throw $errorMessage
    }
    $getClonedAndModifiedHashtablePath = Join-Path $PSScriptRoot 'Get-ClonedAndModifiedHashtable.ps1'
    if (-not (Get-Command -Name 'Get-ClonedAndModifiedHashtable' -CommandType Function -ErrorAction SilentlyContinue) -and
        -not (Test-Path -LiteralPath $getClonedAndModifiedHashtablePath -PathType Leaf)) {
      $errorMessage = "Required helper 'Get-ClonedAndModifiedHashtable' was not found at '$getClonedAndModifiedHashtablePath'."
      Write-HostSettingsMessage -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # Candidate ordering lives in Get-IACHostSettingsCandidatePath so it can be tested without a
    # real ATAP.IAC checkout. The sprint worktree is DISCOVERED, never hard-coded: a literal here
    # named the Sprint 0007 worktree and quietly stopped matching when that sprint ended (SC-0252).
    $searchRoots = @(
      (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub')
      'C:\Dropbox\whertzing\GitHub'
    )
    $programFilesResourcePath = if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
      Join-Path $env:ProgramFiles 'Powershell\Modules\ATAP.Utilities.Powershell\Resources'
    } else {
      $null
    }

    if (-not (Get-Command -Name 'Get-IACHostSettingsCandidatePath' -CommandType Function -ErrorAction SilentlyContinue)) {
      # Running this file straight from source, without the module import that dot-sources private\.
      . (Join-Path $PSScriptRoot '..\private\Get-IACHostSettingsCandidatePath.ps1')
    }

    # Task 14.62 fast path. Discovery below enumerates $searchRoots with Get-ChildItem, and one
    # of those roots is the Dropbox GitHub tree. Every directory there carries a Cloud Files
    # reparse attribute, so enumerating it forces placeholder resolution: measured at ~1.15 s,
    # which was roughly 40% of TOTAL PowerShell profile startup on utat022 - paid by every shell,
    # to locate a file whose location is already known.
    #
    # $PSHOME\HostSettings.ps1 is the symlink the sprint lifecycle maintains, pointing at the
    # active ATAP.IAC worktree. Probing it first is not a hard-coded sprint path (the SC-0252
    # regression): the link IS the discovery mechanism, retargeted at each sprint boundary. When
    # it is absent or dangling, discovery runs exactly as before.
    $hostSettingsScript = $null
    $fastPathCandidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($IACBasePath)) {
      # An explicit caller-supplied base always outranks anything discovered.
      foreach ($relativePath in @('Windows\HostSettings.ps1', 'HostSettings.ps1')) {
        $fastPathCandidates.Add((Join-Path $IACBasePath $relativePath))
      }
    }
    if (-not [string]::IsNullOrWhiteSpace($PSHOME)) {
      $fastPathCandidates.Add((Join-Path $PSHOME 'HostSettings.ps1'))
    }
    foreach ($fastCandidate in $fastPathCandidates) {
      if (-not (Test-Path -LiteralPath $fastCandidate -PathType Leaf)) { continue }

      # $PSHOME\HostSettings.ps1 is a SYMLINK into the ATAP.IAC worktree. Dot-sourcing a link
      # sets $PSScriptRoot to the LINK's directory, not the target's - and HostSettings.ps1
      # resolves its HostSettings.IAC.Fragments\ siblings from $PSScriptRoot. Using the link path
      # directly therefore loads the script but finds none of its fragments, producing a
      # half-built settings hashtable. Resolve to the real file so $PSScriptRoot lands beside the
      # fragments; if the link is dangling, fall through to full discovery.
      $resolvedCandidate = $fastCandidate
      try {
        $candidateItem = Get-Item -LiteralPath $fastCandidate -Force -ErrorAction Stop
        if ($candidateItem.LinkTarget) {
          $linkTarget = $candidateItem.LinkTarget
          if (-not [System.IO.Path]::IsPathRooted($linkTarget)) {
            $linkTarget = Join-Path (Split-Path -Path $fastCandidate -Parent) $linkTarget
          }
          if (-not (Test-Path -LiteralPath $linkTarget -PathType Leaf)) { continue }
          $resolvedCandidate = $linkTarget
        }
      }
      catch {
        continue
      }

      # A HostSettings.ps1 without its fragments directory is unusable; let discovery try.
      $fragmentDirectory = Join-Path (Split-Path -Path $resolvedCandidate -Parent) 'HostSettings.IAC.Fragments'
      if (-not (Test-Path -LiteralPath $fragmentDirectory -PathType Container)) {
        Write-HostSettingsMessage -Level Verbose -Message "Fast-path candidate '$resolvedCandidate' has no HostSettings.IAC.Fragments directory; falling back to discovery."
        continue
      }

      $hostSettingsScript = $resolvedCandidate
      Write-HostSettingsMessage -Level Verbose -Message "Resolved HostSettings.ps1 via fast path '$fastCandidate' -> '$resolvedCandidate'; skipped search-root enumeration."
      break
    }

    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    if (-not $hostSettingsScript) {
      foreach ($candidate in (Get-IACHostSettingsCandidatePath -IACBasePath $IACBasePath -SearchRoot $searchRoots -ProgramFilesResourcePath $programFilesResourcePath)) {
        Add-CandidatePath -CandidatePaths $candidatePaths -Path $candidate
      }
    }

    foreach ($candidate in $candidatePaths) {
      foreach ($relativePath in @('Windows\HostSettings.ps1', 'HostSettings.ps1')) {
        $probePath = Join-Path $candidate $relativePath
        if (Test-Path -LiteralPath $probePath -PathType Leaf) {
          $hostSettingsScript = $probePath
          break
        }
      }

      if ($hostSettingsScript) {
        break
      }
    }

    if ([string]::IsNullOrWhiteSpace($hostSettingsScript)) {
      $errorMessage = "HostSettings.ps1 not found under any candidate base path: $($candidatePaths -join '; ')"
      Write-HostSettingsMessage -Level Error -Message $errorMessage
      throw $errorMessage
    }

    $hostSettingsScript = [System.IO.Path]::GetFullPath($hostSettingsScript)
    Write-HostSettingsMessage -Level Verbose -Message "Resolved HostSettings.ps1 to '$hostSettingsScript'"
  }

  process {
    if (-not $PSCmdlet.ShouldProcess($hostName, "Build host settings hashtable from '$hostSettingsScript'")) {
      return
    }

    try {
      $settingsHash = & {
        param(
          [string] $Name,
          [string] $Path,

          [string] $GetClonedAndModifiedHashtablePath
        )

        if (-not (Get-Command -Name 'Get-ClonedAndModifiedHashtable' -CommandType Function -ErrorAction SilentlyContinue)) {
          . $GetClonedAndModifiedHashtablePath
        }

        $maxHostSettingsLoadAttempts = 5
        $hostSettingsLoadDelayMilliseconds = 200
        for ($attempt = 1; $attempt -le $maxHostSettingsLoadAttempts; $attempt++) {
          try {
            . $Path
            break
          } catch {
            $exceptionMessages = [System.Collections.Generic.List[string]]::new()
            $currentException = $_.Exception
            while ($null -ne $currentException) {
              [void] $exceptionMessages.Add($currentException.Message)
              $currentException = $currentException.InnerException
            }

            $isSharingViolation = (($exceptionMessages -join "`n") -match 'being used by another process|process cannot access the file')
            if (-not $isSharingViolation -or $attempt -ge $maxHostSettingsLoadAttempts) {
              throw
            }

            Start-Sleep -Milliseconds $hostSettingsLoadDelayMilliseconds
            $hostSettingsLoadDelayMilliseconds = [Math]::Min(($hostSettingsLoadDelayMilliseconds * 2), 2000)
          }
        }

        $innerGetHostSettings = Get-Command -Name 'Get-HostSettings' -CommandType Function -ErrorAction Stop
        $innerFunctionFile = if ($innerGetHostSettings.ScriptBlock.File) {
          [System.IO.Path]::GetFullPath($innerGetHostSettings.ScriptBlock.File)
        } else {
          ''
        }

        if ($innerFunctionFile -ne $Path) {
          throw "HostSettings.ps1 did not define the expected inner Get-HostSettings function. Resolved function file: '$innerFunctionFile'."
        }

        Get-HostSettings -hostName $Name
      } $hostName $hostSettingsScript $getClonedAndModifiedHashtablePath

      if ($null -eq $settingsHash) {
        throw "HostSettings.ps1 returned null for hostName '$hostName'. Confirm the host is recognized in the IAC dispatch switch."
      }

      if (-not ($settingsHash -is [hashtable])) {
        throw "HostSettings.ps1 returned '$($settingsHash.GetType().FullName)' for hostName '$hostName'; expected System.Collections.Hashtable."
      }

      Update-BuildMasterApplicationMap -SettingsHash $settingsHash
      return $settingsHash
    } catch {
      $errorMessage = "Failed to build host settings for '$hostName' from '$hostSettingsScript'. Exception: $($_.Exception.Message)"
      Write-HostSettingsMessage -Level Error -Message $errorMessage
      throw
    }
  }

  end {
    Write-HostSettingsMessage -Level Debug -Message "Leaving $fn"
  }
}
