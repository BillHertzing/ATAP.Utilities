
#############################################################################
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: Write examples
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-SessionKey {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern'  )]
  param(
    [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [Alias('In')]
    [string] $hydrusAccessKey
    , [parameter()]
    [Alias('Perms')]
    [string] $requestedPermissions
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $hydrusAPIProtocol
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $hydrusAPIServer
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [int] $hydrusAPIPort
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [switch] $PassThru
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [Alias('CN')]
    [string[]] $computerNames
  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $originalPSBoundParameters = $PSBoundParameters # to allow debugging
    # ensure the function Get-ParameterValueFromNeoConfigurationRoot from the ATAP.Utilities.Powershell package is loaded
    # ToDo: require or import ATAP.Utilities.Powershell
    . $(Join-Path $([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities', 'src', 'ATAP.Utilities.PowerShell', 'public', 'Get-ParameterValueFromNeoConfigurationRoot.ps1')


    if ($hydrusAccessKey -or $requestedPermissions -or $hydrusAPIProtocol -or $hydrusAPIServer -or $hydrusAPIPort -or $PassThru -or $computerNames) {
      # Not from pipeline
      $noArgumentsSupplied = $false
      # Get values for any arguments not supplied
      if (-not $PSBoundParameters.ContainsKey('hydrusAccessKey')) {
        # Not on command line
        if (-not $(Test-Path Env:HYDRUS_ACCESS_KEY )) {
          # Not as an envrionment variable
          # never stored in global settings
          # ToDo: if in interactive mode, get it from the user
          $message = 'the HydrusAccessKey is not supplied on the command line nor in the environment'
          Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
          # toDo catch the errors, add to 'Problems'
          Throw $message
        }
      }
      $hydrusAPIProtocol = Get-ParameterValueFromNeoConfigurationRoot 'hydrusAPIProtocol' $global:configRootKeys['hydrusAPIProtocolConfigRootKey'] $originalPSBoundParameters
      $hydrusAPIServer = Get-ParameterValueFromNeoConfigurationRoot 'hydrusAPIServer' $global:configRootKeys['hydrusAPIServerConfigRootKey'] $originalPSBoundParameters
      $hydrusAPIPort = Get-ParameterValueFromNeoConfigurationRoot 'hydrusAPIPort' $global:configRootKeys['hydrusAPIPortConfigRootKey'] $originalPSBoundParameters
    }
    else {
      $noArgumentsSupplied = $true
    }

    $page = 'session_key'
    $webRequestArgs = @()
    $webRequestArgsString = $webRequestArgs -join '&'
    switch ($PSCmdlet.ParameterSetName) {
      'DefaultParameterSetNameReplacementPattern' {
      }
      default { throw 'that ParameterSetName has not been implemented yet' }
    }

    function InternalGetSessionKey {

      Write-PSFMessage -Level Debug -Message $("-ComputerName $computername -hydrusAccessKey $hydrusAccessKey -hydrusAPIProtocol $hydrusAPIProtocol -hydrusAPIServer $hydrusAPIServer -hydrusAPIPort $hydrusAPIPort -page $page -webRequestArgsString $webRequestArgsString")
      $result = ''
      switch ($PSCmdlet.ParameterSetName) {
        'DefaultParameterSetNameReplacementPattern' {
          $headers = @{'Hydrus-Client-API-Access-Key' = $hydrusAccessKey }
          $URI = [UriBuilder]::new($hydrusAPIProtocol, $hydrusAPIServer, $hydrusAPIPort, $page, $webRequestArgsString)
          # ToDo: wrap in a try-catch and a Polly-like wrapper, include timeout, etc.
          $sessionKey = $($(Invoke-WebRequest -Uri $URI.uri -Headers $headers).Content | ConvertFrom-Json).session_key
          if ($PassThru) {
            $result = @{
              SessionKey           = $sessionKey
              HydrusSessionKey      = $hydrusSessionKey
              RequestedPermissions = $requestedPermissions
              HydrusAPIProtocol    = $hydrusAPIServer
              HydrusAPIServer      = $hydrusAPIServer
              HydrusAPIPort        = $hydrusAPIPort
              ComputerNames        = $computerNames
            }

          }
          else {
            $sessionKey
          }
        }
        # ToDo add the other two kinds of vaults
      }
      $result
    }
  }

  PROCESS {
    if ($noArgumentsSupplied) {
      # none of the cmdlets arguments have any values passed
      # possibly called from pipeline, either by property value, or just a standalone call expecting to use all default values
      if ($input.Count) {
        # called from a pipeline
        # ToDo - fix this block
        foreach ($obj in $input) {
          # If the input is a PSobject with properties, make sure it has hydrusAccessKey
          if ($obj.PSobject.Properties.Name -notcontains 'hydrusAccessKey') {
            $message = 'the HydrusAccessKey is not supplied on the command line nor in the environment'
            Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
            # toDo catch the errors, add to 'Problems'
            Throw $message
          } else {
             # ToDo - Fix this block
             $message = 'ToDo: pipelione process of objects with properties not yet supported'
             Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
             # toDo catch the errors, add to 'Problems'
             Throw $message
            # deconstruct the pipeline object's properties
            # $hydrusAccessKey = $obj.PSobject.Properties['hydrusAccessKey']
            # Write-Output $(InternalGetSessionKey)
          }

        }
      }
      else {
        # not called from a pipeline, but no arguments are supplied. That is an error because the hydrusAccessKey has to be supplied, either from a command line argument or from an environment variable
        $message = 'the HydrusAccessKey is not supplied on the command line nor in the environment'
        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
    }
    else {
      # Not being used in a pipeline
      Write-Output $(InternalGetSessionKey)
    }
  }


  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}
#############################################################################

