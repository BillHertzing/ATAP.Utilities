
<#
.SYNOPSIS
  Resolves a parameter value using a priority chain: PSBoundParameters → environment variable → NeoConfigurationRoot settings → DefaultValue.

.DESCRIPTION
  Implements the NeoConfigurationRoot resolution pattern. For a given ParameterName, the function
  tries each source in priority order and returns the first non-null result:
    1. originalPSBoundParameters (caller's $PSBoundParameters)
    2. Environment variable whose name matches ParameterName
    3. Settings hashtable/object at the path specified by -dottedPath (defaults to ParameterName)
    4. -DefaultValue

  If -AsType is supplied, coercion is applied to the final resolved value regardless of which
  priority source produced it. Boolean coercion understands 'yes/no', 'true/false', '1/0', 'on/off'.

  ⚠ IMPORTANT — Environment Variable Collision:
    Priority 2 checks for an environment variable named exactly like ParameterName. If the caller
    uses a ParameterName that coincidentally matches a common Windows or shell environment variable
    (e.g. 'Path', 'Host', 'Environment', 'Username', 'ComputerName', 'Temp', 'SystemRoot'), the
    environment variable value will be returned instead of the settings value. Always use
    application-specific, namespaced ParameterNames (e.g. 'MyApp_DbHost' rather than 'Host').

.PARAMETER ParameterName
  The name of the parameter to resolve. Used as the environment variable key (priority 2) and,
  when -dottedPath is omitted, as the settings key (priority 3). Must not match a common OS
  environment variable name unless that environment variable value is intentionally authoritative.

.PARAMETER originalPSBoundParameters
  The $PSBoundParameters hashtable captured in the calling function's Begin block.

.PARAMETER dottedPath
  Dot-separated path into the Settings object (e.g. 'Database.Host'). Defaults to ParameterName.

.PARAMETER Settings
  Hashtable or PSCustomObject to search. Falls back to $script:Settings then $global:settings.

.PARAMETER DefaultValue
  Value returned when all higher-priority sources produce null.

.PARAMETER AllowMissing
  When set, returns $null instead of throwing if nothing resolves.

.PARAMETER AsType
  .NET type to coerce the resolved value to after resolution. Applied uniformly across all sources.

.PARAMETER ValidValues
  Allowed string values for the resolved result (case-insensitive). Returns the correctly-cased
  entry from this list. Throws if the resolved value is not in the list.

.OUTPUTS
  System.Object — the resolved (and optionally coerced) parameter value.

.EXAMPLE
  Get-PVal -ParameterName 'SqlInstance' -originalPSBoundParameters $PSBoundParameters -Settings $global:settings -DefaultValue 'localhost'

.NOTES
  AI assisted using Powershell.instructions.md as guidelines
  Alias: Get-PVal
  See also: Resolve-ParameterValueToList (obsolete — use -ValidValues instead).

.LINK
  Resolve-ParameterValueToList
#>
function Get-ParameterValueFromNeoConfigurationRoot {
  [Alias('Get-PVal')]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
    [ValidateScript({ $_ -is [string] -or $_ -is [hashtable] -or $_ -is [PSCustomObject] })]
    $ParameterName,

    [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
    $originalPSBoundParameters,

    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true)]
    [string]$dottedPath, # if not in $PSBoundParameters, the value will be "$global:settings" from $PSDefaultParameterValues

    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true)]
    [hashtable]$Settings, # if not in $PSBoundParameters, the value will be "$global:settings" from $PSDefaultParameterValues

    [Parameter(Mandatory = $false, Position = 4, ValueFromPipelineByPropertyName = $true)]
    [AllowNull()]
    [object]$DefaultValue = $null,

    [Parameter(Mandatory = $false, Position = 5, ValueFromPipelineByPropertyName = $true)]
    [switch]$AllowMissing,
    [Parameter(Mandatory = $false, Position = 6, ValueFromPipelineByPropertyName = $true)]
    [Type]$AsType,

    [Parameter(Mandatory = $false, Position = 7, ValueFromPipelineByPropertyName = $true)]
    [string[]]$ValidValues
  )
  # Copilot instruction: do not log cmdlet entry or exit
  Begin {
    function Get-NestedValue {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)][object]$Root,
        [Parameter(Mandatory)][string]$dottedPath,
        [ref]$Found
      )
      $parts = $dottedPath -split '\.'
      $cur = $Root
      foreach ($p in $parts) {
        if ($cur -is [hashtable]) {
          if ($cur.ContainsKey($p)) {
            $cur = $cur[$p]
          }
          else {
            $Found.Value = $false; return $null
          }
        }
        elseif ($cur -is [PSCustomObject]) {
          if (($cur | Get-Member -Name $p -MemberType NoteProperty, Property)) {
            $cur = $cur.$p
          }
          else {
            $Found.Value = $false; return $null
          }
        }
        else {
          $Found.Value = $false; return $null
        }
      }
      $Found.Value = $true
      return $cur
    }

    function Resolve-SettingsValue {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({
            if ($_ -is [string]) { return $_ -match '^[\w\.-]+$' }
            elseif ($_ -is [hashtable] -or $_ -is [PSCustomObject]) { return ($_ | Get-Member -Name Path) }
            throw "ParameterName must be a dotted string path (e.g. 'a.b.c') or a hashtable/PSCustomObject with a 'Path' property."
          })]
        $dottedPath,

        [Parameter(ValueFromPipelineByPropertyName)]
        [hashtable]$Settings,

        [object]$Default = $null,
        [switch]$AllowMissing,

        # Optionally coerce the result to a type, e.g. ([string]) or ([int])
        [Type]$AsType
      )

      # Resolve the effective settings source
      $effective = if ($PSBoundParameters.ContainsKey('Settings') -and $Settings) { $Settings }
      elseif ($script:Settings) { $script:Settings }
      elseif ($global:settings) { $global:settings }
      else { @{} }

      $dottedPath = if ($dottedPath -is [string]) { $dottedPath } else { $dottedPath.Path }

      $found = $false
      $value = Get-NestedValue -Root $effective -dottedPath $dottedPath -Found ([ref]$found)

      if (-not $found) {
        if ($dottedPath -isnot [string] -and ($dottedPath | Get-Member -Name Default)) {
          $value = $dottedPath.Default
          $found = $true
        }
        elseif ($AllowMissing) {
          $value = $Default
        }
        else {
          throw "dottedPath '$dottedPath' not found in settings."
        }
      }

      if ($AsType) {
        # Custom boolean coercion (string "No" -> $false, etc.)
        if ($AsType -eq [bool]) {
          if ($value -is [string]) {
            $norm = $value.Trim().ToLowerInvariant()
            switch ($norm) {
              { $_ -in @('true', 't', 'yes', 'y', '1', 'on') } { $value = $true; break }
              { $_ -in @('false', 'f', 'no', 'n', '0', 'off') } { $value = $false; break }
              default { throw "Cannot convert '$value' to Boolean." }
            }
          }
          else {
            # Non-string: rely on PowerShell truthiness only for real bools
            if ($value -isnot [bool]) {
              $value = [bool]$value
            }
          }
        }
        else {
          try { $value = $value -as $AsType } catch { throw "Failed to coerce '$dottedPath' to type $AsType : $_" }
        }
      }
      return $value
    }
  }
  Process {  }
  End {
    # Debug: Report caller information
    if ($DebugPreference -ne 'SilentlyContinue') {
      $callStack = Get-PSCallStack
      $caller = $callStack[1]
      Write-Debug "Get-PVal called from: $($caller.ScriptName):$($caller.ScriptLineNumber) in function '$($caller.FunctionName)' for parameter '$ParameterName'"
    }

    # If dottedPath is not provided, use ParameterName as the path
    if (-not $dottedPath) {
      $dottedPath = $ParameterName
    }

    $resolvedValue = $null
    $resolved = $false

    # 1. If parameter is in originalPSBoundParameters, use that value
    if ($originalPSBoundParameters.ContainsKey($parameterName)) {
      $resolvedValue = $originalPSBoundParameters[$parameterName]
      $resolved = $true
    }

    # 2. If parameter is in environment variable, use that value
    if (-not $resolved -and (Test-Path "Env:$parameterName")) {
      $resolvedValue = (Get-Item -Path "Env:$parameterName").Value
      $resolved = $true
    }

    # 3. Try to get from settings via dottedPath (raw value; AsType applied uniformly below)
    if (-not $resolved) {
      try {
        $settingsValue = Resolve-SettingsValue -dottedPath $dottedPath -Settings $Settings -AllowMissing:$true
        if ($null -ne $settingsValue) {
          $resolvedValue = $settingsValue
          $resolved = $true
        }
      }
      catch {
        # Settings lookup failed, continue to check DefaultValue
      }
    }

    # 4. If DefaultValue is not null, use it
    if (-not $resolved -and $null -ne $DefaultValue) {
      $resolvedValue = $DefaultValue
      $resolved = $true
    }

    # 5. If not resolved and not AllowMissing, throw
    if (-not $resolved) {
      if ($AllowMissing) {
        return $null
      }
      else {
        throw "Parameter '$ParameterName' not found in PSBoundParameters, environment variables, or settings path '$dottedPath', and no DefaultValue was provided."
      }
    }

    # 6. If ValidValues specified, validate the resolved value against the allowed list (case-insensitive)
    if ($ValidValues -and $null -ne $resolvedValue) {
      $lc = $resolvedValue.ToString().ToLowerInvariant()
      $match = $ValidValues | Where-Object { $_.ToLowerInvariant() -eq $lc }
      if ($null -eq $match) {
        throw "Parameter '$ParameterName' value '$resolvedValue' is not valid. Must be one of: $($ValidValues -join ', ')"
      }
      $resolvedValue = $match
    }

    # 7. Apply AsType coercion uniformly, regardless of which priority resolved the value
    if ($AsType -and $null -ne $resolvedValue) {
      if ($AsType -eq [bool]) {
        if ($resolvedValue -is [string]) {
          $norm = $resolvedValue.Trim().ToLowerInvariant()
          switch ($norm) {
            { $_ -in @('true', 't', 'yes', 'y', '1', 'on') } { $resolvedValue = $true; break }
            { $_ -in @('false', 'f', 'no', 'n', '0', 'off') } { $resolvedValue = $false; break }
            default { throw "Cannot convert '$resolvedValue' to Boolean for parameter '$ParameterName'." }
          }
        }
        else {
          if ($resolvedValue -isnot [bool]) { $resolvedValue = [bool]$resolvedValue }
        }
      }
      else {
        try { $resolvedValue = $resolvedValue -as $AsType }
        catch { throw "Failed to coerce parameter '$ParameterName' to type $AsType : $_" }
      }
    }

    return $resolvedValue
  }
}
