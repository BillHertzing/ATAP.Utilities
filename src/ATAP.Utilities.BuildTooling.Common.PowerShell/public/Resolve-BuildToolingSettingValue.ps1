function Resolve-BuildToolingSettingValue {
  <#
  .SYNOPSIS
  Resolves a named BuildTooling setting from the ATAP configuration globals.

  .DESCRIPTION
  Reads a setting from $global:Settings by its direct name or by a key mapped
  through $global:configRootKeys. Direct settings take precedence over mapped
  keys, and null or whitespace-only values are ignored.

  .PARAMETER Name
  The logical BuildTooling setting name to resolve.

  .OUTPUTS
  System.Object. The configured setting value.

  .EXAMPLE
  Resolve-BuildToolingSettingValue -Name 'ProGetAdminUriHost'

  Resolves the ProGet administration host from the initialized ATAP settings.

  .NOTES
  Requires $global:Settings to have been initialized by the host configuration
  bootstrap.

  .LINK
  Initialize-ATAPConfigurationGlobals
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'This resolver reads the repository-standard global configuration hashtables.'
  )]
  [CmdletBinding()]
  [OutputType([object])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.Common.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ($null -eq $global:Settings) {
      throw '$global:Settings is not initialized. Load host settings before resolving BuildTooling settings.'
    }
  }

  process {
    $candidateKeys = [System.Collections.Generic.List[string]]::new()
    [void]$candidateKeys.Add($Name)

    if ($null -ne $global:configRootKeys) {
      foreach ($configKeyName in @("${Name}ConfigRootKey", $Name)) {
        if ($global:configRootKeys.ContainsKey($configKeyName)) {
          [void]$candidateKeys.Add([string]$global:configRootKeys[$configKeyName])
        }
      }
    }

    foreach ($candidateKey in ($candidateKeys | Select-Object -Unique)) {
      if ([string]::IsNullOrWhiteSpace($candidateKey)) {
        continue
      }
      if ($global:Settings.ContainsKey($candidateKey)) {
        $value = $global:Settings[$candidateKey]
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
          return $value
        }
      }
    }

    throw "Setting '$Name' could not be resolved from `$global:Settings."
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
