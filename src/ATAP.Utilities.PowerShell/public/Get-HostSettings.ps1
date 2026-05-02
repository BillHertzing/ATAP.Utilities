<#
.SYNOPSIS
Builds the per-host settings hashtable for the named host by loading the data fragments published by the ATAP.IAC repository.

.DESCRIPTION
Resolves the location of the ATAP.IAC HostSettings.ps1 (sprint worktree, stable worktree, or installed module Resources folder), ensures prerequisite helpers (Get-ClonedAndModifiedHashtable and $global:configRootKeys) are loaded, then dot-sources the IAC HostSettings.ps1 inside an isolated child scope. The IAC file defines a same-named inner Get-HostSettings function which drives a switch-on-hostname dispatch and clones/modifies the $HostsType1 base hashtable populated by the IAC fragment files. The inner function is invoked from inside the child scope, where local-scope function resolution wins over this module-exported wrapper.

The typical caller is the AllUsersAllHostsV7CoreProfile.ps1 startup profile:

  $global:settings = Get-HostSettings $hostName

.PARAMETER hostName
Hostname (case-insensitive) used by the IAC HostSettings.ps1 dispatch switch to select the correct base hashtable and per-host overrides.

.PARAMETER IACBasePath
Optional. Root of the ATAP.IAC repository or worktree to use as the source of HostSettings.ps1. Resolution order when not supplied:
  1. -IACBasePath parameter
  2. ATAP_IAC_BASE_PATH environment variable
  3. $([Environment]::GetFolderPath('MyDocuments'))\GitHub\ATAP.IAC
  4. C:\Dropbox\whertzing\GitHub\ATAP.IAC
  5. $env:ProgramFiles\Powershell\Modules\ATAP.Utilities.Powershell\Resources

Within each candidate, both <root>\Windows\HostSettings.ps1 and <root>\HostSettings.ps1 are probed.

.OUTPUTS
System.Collections.Hashtable. The populated per-host settings hashtable.

.EXAMPLE
$global:settings = Get-HostSettings 'utat022'

.EXAMPLE
$global:settings = Get-HostSettings -hostName $env:COMPUTERNAME -IACBasePath 'C:\Dropbox\whertzing\GitHub\ATAP.IAC-wt-9-Sprint-0007-work-items'

.NOTES
AI assisted using Powershell.instructions.md as guidelines.
Requires $global:configRootKeys to be populated first; call Set-GlobalConfigRootKeys (from ATAP.Utilities.ConfigRootKeys.Powershell) before this cmdlet.

.LINK
https://github.com/BillHertzing/ATAP.Utilities
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
    $mn = 'ATAP.Utilities.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn for hostName '$hostName'"

    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrEmpty($IACBasePath)) {
      [void]$candidatePaths.Add($IACBasePath)
    }
    $envIACPath = [System.Environment]::GetEnvironmentVariable('ATAP_IAC_BASE_PATH', 'Process')
    if ([string]::IsNullOrEmpty($envIACPath)) {
      $envIACPath = [System.Environment]::GetEnvironmentVariable('ATAP_IAC_BASE_PATH', 'User')
    }
    if (-not [string]::IsNullOrEmpty($envIACPath)) {
      [void]$candidatePaths.Add($envIACPath)
    }
    [void]$candidatePaths.Add((Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub\ATAP.IAC'))
    [void]$candidatePaths.Add('C:\Dropbox\whertzing\GitHub\ATAP.IAC')
    [void]$candidatePaths.Add((Join-Path $env:ProgramFiles 'Powershell\Modules\ATAP.Utilities.Powershell\Resources'))

    $hostSettingsScript = $null
    foreach ($candidate in $candidatePaths) {
      foreach ($rel in @('Windows\HostSettings.ps1', 'HostSettings.ps1')) {
        $probe = Join-Path $candidate $rel
        if (Test-Path -LiteralPath $probe -PathType Leaf) {
          $hostSettingsScript = $probe
          break
        }
      }
      if ($hostSettingsScript) { break }
    }

    if ([string]::IsNullOrEmpty($hostSettingsScript)) {
      $errorMessage = "HostSettings.ps1 not found under any candidate base path: $($candidatePaths -join '; ')"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Resolved HostSettings.ps1 to '$hostSettingsScript'"

    if (-not (Test-Path -LiteralPath 'Function:\Get-ClonedAndModifiedHashtable')) {
      $helperPath = Join-Path $PSScriptRoot 'Get-ClonedAndModifiedHashtable.ps1'
      if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
        $errorMessage = "Required helper Get-ClonedAndModifiedHashtable.ps1 not found at '$helperPath'."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourcing helper '$helperPath'"
      . $helperPath
    }

    if (-not $global:configRootKeys -or $global:configRootKeys.Count -eq 0) {
      $errorMessage = '$global:configRootKeys is not populated. Call Set-GlobalConfigRootKeys (ATAP.Utilities.ConfigRootKeys.Powershell) before Get-HostSettings.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }

  process {
    if ($PSCmdlet.ShouldProcess($hostName, "Build host settings hashtable from '$hostSettingsScript'")) {
      try {
        # Dot-source HostSettings.ps1 inside an isolated child scope. The IAC
        # script defines a same-named local Get-HostSettings; local-scope
        # function resolution wins over this module-exported wrapper for the
        # duration of the script-block invocation.
        $settingsHash = & {
          param($name, $path)
          . $path
          Get-HostSettings -hostName $name
        } $hostName $hostSettingsScript

        if ($null -eq $settingsHash) {
          $errorMessage = "HostSettings.ps1 returned `$null for hostName '$hostName'. Confirm the host is recognized in the IAC dispatch switch."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        return $settingsHash
      } catch {
        $errorMessage = "Failed to build host settings for '$hostName' from '$hostSettingsScript'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn"
  }
}
