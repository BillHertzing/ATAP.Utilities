#region Get-ATAPIACConstant
<#
.SYNOPSIS
  Bootstrap accessor for ATAP.IAC constant values.
.DESCRIPTION
  Returns the value of a named ATAP.IAC constant. The lookup is performed in
  two stages:

  1. **Profile-loaded globals** — checks `$global:settings[$global:configRootKeys[$Name]]`
     for back-compat with interactive sessions where the profile has already
     populated these hashes.

  2. **Direct file load** — if the globals are absent or the key is not found,
     locates the ATAP.IAC repository's `constants/` folder by walking up from
     the current git root (`git rev-parse --show-toplevel`) to a sibling
     `ATAP.IAC` directory, then imports every `*.psd1` found there and reads
     the named key.

  This two-stage approach means the cmdlet works both in an interactive
  developer session (where $global:settings is populated) and in a headless
  BuildMaster agent shell where no profile is loaded.

  Throws a clear terminating error if neither path can resolve the requested
  constant.
.PARAMETER Name
  The constant key name, e.g. `PowerShellGetFeed_Alpha` or
  `PassingCodeCoveragePct_PowerShell`.
.INPUTS
  None. This cmdlet does not accept pipeline input.
.OUTPUTS
  The constant value — typically a [string] or [int], but may be any type
  stored in the constants psd1.
.EXAMPLE
  PS> Get-ATAPIACConstant -Name 'PowerShellGetFeed_Alpha'
  PowershellGet-development
.EXAMPLE
  PS> Get-ATAPIACConstant -Name 'PassingCodeCoveragePct_PowerShell'
  70
.NOTES
  AI assisted using Powershell.instructions.md as guidelines
  Task: T-30 (Phase 2) of 5-Tier Swarm Tasks — module.build.ps1
.LINK
  src/ATAP.Utilities.BuildTooling.PowerShell/Documentation/5Tier%20tasks%20for%20module.build.ps1.md
#>
function Get-ATAPIACConstant {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Name
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName

    # Check and populate simple parameter: Name
    if ([string]::IsNullOrWhiteSpace($Name)) {
      $msg = "Parameter 'Name' must not be null or empty."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn — looking up constant '$Name'" -Tag 'Trace'
  }

  process {
    # -----------------------------------------------------------------------
    # Stage 1: profile-loaded globals
    # -----------------------------------------------------------------------
    if ($null -ne $global:configRootKeys -and $global:configRootKeys.ContainsKey($Name)) {
      $settingsKey = $global:configRootKeys[$Name]
      if ($null -ne $global:settings -and $global:settings.ContainsKey($settingsKey)) {
        $value = $global:settings[$settingsKey]
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved '$Name' from global:settings (key '$settingsKey')" -Tag 'IACConstant'
        return $value
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Key '$Name' not found in global:settings; falling back to direct file load" -Tag 'IACConstant'

    # -----------------------------------------------------------------------
    # Stage 2: locate ATAP.IAC sibling repo and load constants/*.psd1
    # -----------------------------------------------------------------------
    try {
      $gitOutput = & git rev-parse --show-toplevel 2>&1
      if ($LASTEXITCODE -ne 0) {
        throw "git rev-parse --show-toplevel failed: $gitOutput"
      }
      $repoRoot = $gitOutput.Trim()
    } catch {
      $msg = "Could not determine git repository root while looking up ATAP.IAC constants. $_"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    # Walk up one level from the repo root to find a sibling ATAP.IAC folder
    $parentDir = Split-Path -Parent $repoRoot
    $iacRoot = Join-Path $parentDir 'ATAP.IAC'

    if (-not (Test-Path $iacRoot -PathType Container)) {
      $msg = "ATAP.IAC repository not found at '$iacRoot'. Cannot resolve constant '$Name'. " +
      'Ensure ATAP.IAC is checked out as a sibling of this repository.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $constantsDir = Join-Path $iacRoot 'constants'
    if (-not (Test-Path $constantsDir -PathType Container)) {
      $msg = "ATAP.IAC constants directory not found at '$constantsDir'. Cannot resolve constant '$Name'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $psd1Files = Get-ChildItem -Path $constantsDir -Filter '*.psd1' -File
    if ($psd1Files.Count -eq 0) {
      $msg = "No *.psd1 files found under '$constantsDir'. Cannot resolve constant '$Name'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    foreach ($psd1 in $psd1Files) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loading constants file '$($psd1.FullName)'" -Tag 'IACConstant'
      $data = Import-PowerShellDataFile -Path $psd1.FullName
      if ($data.ContainsKey($Name)) {
        $value = $data[$Name]
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved '$Name' from '$($psd1.Name)'" -Tag 'IACConstant'
        return $value
      }
    }

    # Neither stage resolved the key
    $msg = "Constant '$Name' was not found in global:settings or in any *.psd1 under '$constantsDir'."
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
    throw $msg
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
#endregion Get-ATAPIACConstant
