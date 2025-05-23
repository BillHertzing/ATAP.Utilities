function Get-ParameterValueFromNeoConfigurationRoot {
  param(
    [string] $parameterName
    , [string] $configRootKeyName
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
    [hashtable] $originalPSBoundParameters
  )
  if (-not $configRootKeyName) {
    # it is null
    $message = 'the configRootKeyName argument passed into this routine is null'
    Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
    # toDo catch the errors, add to 'Problems'
    Throw $message
  }
  if ($originalPSBoundParameters) {
    # $originalPSBoundParameters is not null
    if (-not $originalPSBoundParameters.ContainsKey($parameterName)) {
      # Not on command line
      # ToDO: ToDo: add test because this returns true if the $global:configRootKeys is null
      if (-not $(Test-Path Env:$configRootKeyName)) {
        # Not as an envrionment variable
        if (-not $global:settings.ContainsKey($configRootKeyName)) {
          # Not in $global:settings
          $message = "the $configRootKeyName is not supplied on the command line nor in the environment nor in the global:settings"
          Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
          # toDo catch the errors, add to 'Problems'
          Throw $message
        } else {
          return $global:settings[$configRootKeyName]
        }
      } else {
        return $(Get-Item -Path "Env:$configRootKeyName").value
      }
    }
    $originalPSBoundParameters[$parameterName]
  } else {
    # $originalPSBoundParameters is null
    # $configRootKeyName is NOT null
    if (-not $(Test-Path Env:$configRootKeyName)) {
      # Not as an envrionment variable
      if (-not $global:settings.ContainsKey($configRootKeyName)) {
        # Not in $global:settings
        $message = "the $configRootKeyName is not supplied on the command line nor in the environment nor in the global:settings"
        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      } else {
        return $global:settings[$configRootKeyName]
      }
    } else {
      # it is an environment variable
      return $(Get-Item -Path "Env:$configRootKeyName").value
    }
  }
}

