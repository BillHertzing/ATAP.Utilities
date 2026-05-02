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

.PARAMETER hostName
Hostname used by the IAC HostSettings.ps1 dispatch switch.

.PARAMETER IACBasePath
Optional root of the ATAP.IAC repository or worktree. When omitted, the
function probes the ATAP.IAC sprint worktree first, then environment, stable
development, and installed-module locations.

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
$global:settings = Get-HostSettings -hostName $env:COMPUTERNAME

.NOTES
Requires $global:configRootKeys to be populated first. Call
Set-GlobalConfigRootKeys before this cmdlet.
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

    function Import-LocalPublicHelper {
      param(
        [Parameter(Mandatory = $true)]
        [string] $Name
      )

      if (Get-Command -Name $Name -CommandType Function -ErrorAction SilentlyContinue) {
        return
      }

      $helperPath = Join-Path $PSScriptRoot "$Name.ps1"
      if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
        throw "Required helper '$Name' was not found at '$helperPath'."
      }

      Write-HostSettingsMessage -Level Debug -Message "Dot-sourcing helper '$helperPath'"
      . $helperPath

      if (-not (Get-Command -Name $Name -CommandType Function -ErrorAction SilentlyContinue)) {
        throw "Dot-sourcing '$helperPath' did not define function '$Name'."
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

    Import-LocalPublicHelper -Name 'Get-ClonedAndModifiedHashtable'
    $getClonedAndModifiedHashtablePath = Join-Path $PSScriptRoot 'Get-ClonedAndModifiedHashtable.ps1'

    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    Add-CandidatePath -CandidatePaths $candidatePaths -Path $IACBasePath
    Add-CandidatePath -CandidatePaths $candidatePaths -Path 'C:\Dropbox\whertzing\GitHub\ATAP.IAC-wt-9-Sprint-0007-work-items'
    Add-CandidatePath -CandidatePaths $candidatePaths -Path ([System.Environment]::GetEnvironmentVariable('ATAP_IAC_BASE_PATH', 'Process'))
    Add-CandidatePath -CandidatePaths $candidatePaths -Path ([System.Environment]::GetEnvironmentVariable('ATAP_IAC_BASE_PATH', 'User'))
    Add-CandidatePath -CandidatePaths $candidatePaths -Path (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub\ATAP.IAC')
    Add-CandidatePath -CandidatePaths $candidatePaths -Path 'C:\Dropbox\whertzing\GitHub\ATAP.IAC'

    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
      Add-CandidatePath -CandidatePaths $candidatePaths -Path (Join-Path $env:ProgramFiles 'Powershell\Modules\ATAP.Utilities.Powershell\Resources')
    }

    $hostSettingsScript = $null
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

        . $Path

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
