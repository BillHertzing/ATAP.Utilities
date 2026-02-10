
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

    # 3. Try to get from settings via dottedPath
    if (-not $resolved) {
      try {
        $settingsValue = Resolve-SettingsValue -dottedPath $dottedPath -Settings $Settings -AllowMissing:$true -AsType $AsType
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

    return $resolvedValue
  }
}
