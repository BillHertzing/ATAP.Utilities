
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
    [object]$Default = $null,
    [Parameter(Mandatory = $false, Position = 5, ValueFromPipelineByPropertyName = $true)]
    [switch]$AllowMissing,
    [Parameter(Mandatory = $false, Position = 6, ValueFromPipelineByPropertyName = $true)]
    [Type]$AsType
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
    # If dottedPath is not provided, use ParameterName as the path
    if (-not $dottedPath) {
      $dottedPath = $ParameterName
    }

    if ($originalPSBoundParameters.ContainsKey($parameterName)) {
      return $originalPSBoundParameters[$parameterName]
    }

    if (-not $(Test-Path "Env:$parameterName")) {
      return Resolve-SettingsValue -dottedPath $dottedPath -Settings $Settings -Default $Default -AllowMissing:$AllowMissing -AsType $AsType
    }
    else {
      return $(Get-Item -Path "Env:$parameterName").value

    }
  }
}
