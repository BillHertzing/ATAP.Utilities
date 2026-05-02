# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Populates $global:configRootKeys by dot-sourcing all *.ConfigRootKeys.ps1 fragment files.

.DESCRIPTION
Bootstraps $global:configRootKeys in a fixed four-phase sequence:

  Phase 1 — Bootstrap: dot-sources and calls Set-CoreConfigRootKeys.ps1 explicitly.
             Creates the hashtable; must complete before any fragment adds keys.

  Phase 2 — Explicit DB keys: dot-sources and calls Databases.ConfigRootKeys.ps1,
             which adds core DB connection key constants and auto-loads all
             Databases.*.ConfigRootKeys.ps1 sub-fragments.

  Phase 3 — Discovery: searches the directory given by -Path for every .ps1 file
             whose base name ends with '.ConfigRootKeys', excluding scripts already
             handled in Phases 1, 2, and 4 to prevent double-loading. Dot-sources
             each match in alphabetical order and invokes the derived Add- function
             if one exists; otherwise runs the top-level code directly.

             Expected discovery fragments:
               Databases.ATAPUtilities.ConfigRootKeys.ps1 — ATAP.Utilities DB name key
               Databases.BuildSets.ConfigRootKeys.ps1    — BuildSets DB name key
               Databases.Gmail.ConfigRootKeys.ps1        — Gmail DB name key
               Databases.PCMSC.ConfigRootKeys.ps1        — PCMSC DB name key
               Databases.Tags.ConfigRootKeys.ps1         — Tags DB name key
               RulesManagement.ConfigRootKeys.ps1        — Rules-Management key constants

  Phase 4 — Explicit BuildMaster and RulesManagement: dot-sources settings
             fragments that define Phase 4 automation paths and endpoints.

  Phase 5 — Explicit package repos: dot-sources and calls
             Add-PackageRepositoriesConfigRootKeys.ps1, the single source of truth
             for ProGet / NuGet / PowerShellGet feed key constants. No sub-fragment
             scan is performed.

.PARAMETER Path
Directory to scan for *.ConfigRootKeys.ps1 fragment files. When omitted, defaults to
the directory containing Set-GlobalConfigRootKeys.ps1 itself, resolved via
$MyInvocation.MyCommand.ScriptBlock.File so it is correct regardless of how this
function was dot-sourced or called.

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Set-GlobalConfigRootKeys

Loads all *.ConfigRootKeys.ps1 fragments from the default location.

.EXAMPLE
Set-GlobalConfigRootKeys -WhatIf

Shows which fragment files would be dot-sourced without executing them.

.EXAMPLE
Set-GlobalConfigRootKeys -Path 'D:\AltRepo\src\ConfigRootKeys\public'

Loads fragments from an alternate directory.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Set-GlobalConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param (
    [Parameter(Mandatory = $false)]
    [string] $Path
  )

  begin {
    $fn = 'Set-GlobalConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Entering function $fn"

    try {
      if (-not (Test-Path -LiteralPath 'Function:\Get-ParameterValueFromNeoConfigurationRoot')) {
        $scriptFile = $MyInvocation.MyCommand.ScriptBlock.File
        $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($scriptFile)) {
          Split-Path -Parent $scriptFile
        } else {
          $PSScriptRoot
        }
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptRoot))
        $helperPath = Join-Path $repoRoot 'src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
        if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
          throw "Get-ParameterValueFromNeoConfigurationRoot helper not found at '$helperPath'."
        }
        . $helperPath
      }
    } catch {
      $errorMessage = "Failed to load Get-ParameterValueFromNeoConfigurationRoot function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Snippet: "Check and populate simple parameter as Type"
    # running Get-PVal on a parameterr called $Path results is the parameter being set to the $env:Path value., not what we want
    #$Path = Get-PVal -ParameterName 'Path' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Path' -DefaultValue $Path -AsType ([string])

    # Default Path to the directory containing this script file.
    # $MyInvocation.MyCommand.ScriptBlock.File is reliable regardless of how the
    # function was dot-sourced or invoked from a different working directory.
    if ([string]::IsNullOrEmpty($Path)) {
      $scriptFile = $MyInvocation.MyCommand.ScriptBlock.File
      if (-not [string]::IsNullOrEmpty($scriptFile)) {
        $Path = [System.IO.Path]::GetDirectoryName($scriptFile)
      } else {
        $Path = $PWD.ProviderPath
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message (
          'Could not resolve script file path via ScriptBlock.File; falling back to current working directory.'
        )
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Scanning '$Path' for *.ConfigRootKeys.ps1 fragments"
  }

  process {
    try {
      if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        $errorMessage = "Fragment directory '$Path' does not exist or is not accessible."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      # ── Phase 1: Bootstrap — Set-CoreConfigRootKeys ───────────────────────
      $coreScript = Join-Path $Path 'Set-CoreConfigRootKeys.ps1'
      if (-not (Test-Path -LiteralPath $coreScript -PathType Leaf)) {
        $errorMessage = "Bootstrap script '$coreScript' not found. Cannot initialize `$global:configRootKeys."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }
      if ($PSCmdlet.ShouldProcess($coreScript, 'Dot-source and invoke Set-CoreConfigRootKeys')) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourcing '$coreScript'" -Tag 'ConfigRootKeys'
        . $coreScript
        Set-CoreConfigRootKeys
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Set-CoreConfigRootKeys completed.'
      }

      # ── Phase 2: Explicit — Add-DatabasesConfigRootKeys ──────────────────
      $dbScript = Join-Path $Path 'Add-DatabasesConfigRootKeys.ps1'
      if (Test-Path -LiteralPath $dbScript -PathType Leaf) {
        if ($PSCmdlet.ShouldProcess($dbScript, 'Dot-source and invoke Add-DatabasesConfigRootKeys')) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourcing '$dbScript'" -Tag 'ConfigRootKeys'
          . $dbScript
          Add-DatabasesConfigRootKeys
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Add-DatabasesConfigRootKeys completed.'
        }
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "No 'Databases.ConfigRootKeys.ps1' found in '$Path'; skipping."
      }

      # # ── Phase 3: Discovery — remaining *.ConfigRootKeys.ps1 fragments ────
      # # Explicitly-handled scripts are excluded to avoid double-loading.
      # $explicitNames = [System.Collections.Generic.HashSet[string]]@(
      #   'Set-CoreConfigRootKeys.ps1',
      #   'Databases.ConfigRootKeys.ps1',
      #   'Add-PackageRepositoriesConfigRootKeys.ps1'
      # )

      # $fragments = @(
      #   Get-ChildItem -LiteralPath $Path -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
      #     Where-Object { $_.BaseName -match '\.ConfigRootKeys$' -and $_.Name -notin $explicitNames } |
      #     Sort-Object Name
      # )

      # if ($fragments.Count -eq 0) {
      #   Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "No additional *.ConfigRootKeys.ps1 fragments found under '$Path'."
      # } else {
      #   Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $($fragments.Count) additional fragment(s) to load."

      #   foreach ($fragment in $fragments) {
      #     if ($PSCmdlet.ShouldProcess($fragment.FullName, 'Dot-source ConfigRootKeys fragment')) {
      #       try {
      #         Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourcing '$($fragment.FullName)'" -Tag 'ConfigRootKeys'
      #         . $fragment.FullName
      #         Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Loaded '$($fragment.Name)'"

      #         $baseName = $fragment.BaseName -replace '\.ConfigRootKeys$', ''
      #         $derivedFn = "Add-${baseName}ConfigRootKeys"
      #         if (Get-Command -Name $derivedFn -CommandType Function -ErrorAction SilentlyContinue) {
      #           Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking '$derivedFn'" -Tag 'ConfigRootKeys'
      #           & $derivedFn
      #         } else {
      #           Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No function '$derivedFn' found after dot-sourcing '$($fragment.Name)'; fragment uses top-level code."
      #         }
      #       } catch {
      #         $errorMessage = "Failed to load '$($fragment.FullName)'. Exception: $($_.Exception.Message)"
      #         Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      #         throw
      #       }
      #     }
      #   }
      # }

      # ── Phase 4: Explicit — BuildMaster and RulesManagement fragments ─────
      foreach ($explicitFragmentName in @('BuildMaster.ConfigRootKeys.ps1', 'RulesManagement.ConfigRootKeys.ps1')) {
        $explicitFragment = Join-Path $Path $explicitFragmentName
        if (Test-Path -LiteralPath $explicitFragment -PathType Leaf) {
          if ($PSCmdlet.ShouldProcess($explicitFragment, 'Dot-source ConfigRootKeys fragment')) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourcing '$explicitFragment'" -Tag 'ConfigRootKeys'
            . $explicitFragment
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Loaded '$explicitFragmentName'."
          }
        } else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "No '$explicitFragmentName' found in '$Path'; skipping."
        }
      }

      # ── Phase 5: Explicit — Add-PackageRepositoriesConfigRootKeys ─────────
      $pkgRepoScript = Join-Path $Path 'Add-PackageRepositoriesConfigRootKeys.ps1'
      if (Test-Path -LiteralPath $pkgRepoScript -PathType Leaf) {
        if ($PSCmdlet.ShouldProcess($pkgRepoScript, 'Dot-source and invoke Add-PackageRepositoriesConfigRootKeys')) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourcing '$pkgRepoScript'" -Tag 'ConfigRootKeys'
          . $pkgRepoScript
          Add-PackageRepositoriesConfigRootKeys
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Add-PackageRepositoriesConfigRootKeys completed.'
        }
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "No 'Add-PackageRepositoriesConfigRootKeys.ps1' found in '$Path'; skipping."
      }
    } catch {
      $errorMessage = "Unhandled error in $fn. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving process block in $fn"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
