
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
Function Get-FileIDs {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern'  )]
  # [OutputType([int[]])] # ToDo investigate OutputType if PassThru is true
  param(
    [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [Alias('In')]
    [string] $hydrusSessionKey
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [Alias('Search')]
    [hashtable[]] $searchParameters
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

    if ($hydrusSessionKey -or $searchParameters -or $hydrusAPIProtocol -or $hydrusAPIServer -or $hydrusAPIPort -or $PassThru -or $computerNames) {
      # Not from pipeline
      $noArgumentsSupplied = $false
      # Get values for any arguments not supplied
      if (-not $PSBoundParameters.ContainsKey('hydrusSessionKey')) {
        # Not on command line
        if (-not $(Test-Path Env:HYDRUS_ACCESS_KEY )) {
          # Not as an envrionment variable
          # never stored in global settings
          # ToDo: if in interactive mode, get it from the user
          $message = 'the HydrusSessionKey is not supplied on the command line nor in the environment'
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
      $hydrusAPIProtocol = Get-ParameterValueFromNeoConfigurationRoot 'hydrusAPIProtocol' $global:configRootKeys['hydrusAPIProtocolConfigRootKey']
      $hydrusAPIServer = Get-ParameterValueFromNeoConfigurationRoot 'hydrusAPIServer' $global:configRootKeys['hydrusAPIServerConfigRootKey']
      $hydrusAPIPort = Get-ParameterValueFromNeoConfigurationRoot 'hydrusAPIPort' $global:configRootKeys['hydrusAPIPortConfigRootKey']
    }

    $page = '/get_files/search_files'
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    function InternalGetFileIDs {
      param(
        [hashtable] $internalSearchParameters
      )

      Write-PSFMessage -Level Debug -Message $("-ComputerName $computername -hydrusSessionKey $hydrusSessionKey -internalSearchParameters $internalSearchParameters -hydrusAPIServer $hydrusAPIServer -hydrusAPIPort $hydrusAPIPort -page $page -webRequestArgsString $webRequestArgsString")
      $headers = @{'Hydrus-Client-API-Access-Key' = $HydrusSessionKey }
      switch ($PSCmdlet.ParameterSetName) {
        'DefaultParameterSetNameReplacementPattern' {
          [void]$sb.Append('?tags=' + $(, $internalSearchParameters['tags'] | ConvertTo-Json) )
        }
        default { throw 'that ParameterSetName has not been implemented yet' }
      }

      $URI = [UriBuilder]::new($hydrusAPIProtocol, $hydrusAPIServer, $hydrusAPIPort, $page, $sb.ToString())
      [void] $sb.Clear()
      # ToDo: wrap in an async try-catch and a Polly-like wrapper, include timeout, and cancellation, etc.
      $response = Invoke-WebRequest -Uri $URI.uri -Headers $headers
      $fileIDs = $($response.Content | ConvertFrom-Json).file_ids
      $fileIDs
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
          # If the input is a PSobject with properties, make sure it has hydrusSessionKey
          if ($obj.PSobject.Properties.Name -notcontains 'hydrusSessionKey') {
            $message = 'the HydrusSessionKey is not supplied on the command line nor in the environment'
            Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
            # toDo catch the errors, add to 'Problems'
            Throw $message
          }
          elseif ($obj -is [hashtable]) {
            # assume the hashtable is a searchParamter
            $searchParameters = $obj
            InternalGetFileIDs $obj
          }

          else {
            # deconstruct the pipeline object's properties
            $PropertyNames = $obj.PSobject.Properties.Name
            for ($PropertyNamesIndex = 0; $PropertyNamesIndex -lt $PropertyNames.Count; $PropertyNamesIndex++) {
              $PropertyName = $PropertyNames[$PropertyNamesIndex]
              switch ($PropertyName) {
                'hydrusSessionKey' { $hydrusSessionKey = $obj.PSobject.Properties['hydrusSessionKey'].value; break }
                'hydrusAPIProtocol' { $hydrusAPIProtocol = $obj.PSobject.Properties['hydrusAPIProtocol'].value; break }
                'hydrusAPIServer' { $hydrusAPIServer = $obj.PSobject.Properties['hydrusAPIServer'].value; break }
                'hydrusAPIPort' { $hydrusAPIPort = $obj.PSobject.Properties['hydrusAPIPort'].value; break }
                'PassThru' { $PassThru = $obj.PSobject.Properties['PassThru'].value; break }
                'computerNames' { $computerNames = $obj.PSobject.Properties['computerNames'].value; break }
                default { # ignore any property names that are not parameters of this cmdlet}
                }
              }
            }
            # $SearchParameters is a hashtable array or a single hashtable
            for ($SearchParametersIndex = 0; $SearchParametersIndex -lt $SearchParameters.Count; $SearchParametersIndex++) {
              $SearchParameter = $SearchParameters[$SearchParametersIndex]
            # ToDo: accumulate any errors and add them to the pipeline object
            # If FileIDs or HashIDs passed as pipeline object parameters
            if ($PassThru) {
             $obj| Add-Member -MemberType NoteProperty -Name 'FileIDs' -Value $(InternalGetFileIDs $SearchParameter)
              Write-Output $obj
            } else {
              Write-Output $(InternalGetFileIDs $SearchParameter)
            }
            }
          }
        }
      }
    }
    else {
      # Not being used in a pipeline
      # $SearchParameters is a hashtable array or a single hashtable
      for ($SearchParametersIndex = 0; $SearchParametersIndex -lt $SearchParameters.Count; $SearchParametersIndex++) {
        $SearchParameter = $SearchParameters[$SearchParametersIndex]
        # ToDo: implement batching
        if ($PassThru) {
          # Create a new object to pass down the pipeline
          $result = [pscustomobject](@{HydrusSessionKey = $hydrusSessionKey
              SearchParameters                         = $searchParameters
              FileIDs                                  = $(InternalGetFileIDs $searchParameter)
            })
          Write-Output $result
        }
        else {
          Write-Output $(InternalGetFileIDs $searchParameter)
        }
      }
    }
  }

  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}
#############################################################################

