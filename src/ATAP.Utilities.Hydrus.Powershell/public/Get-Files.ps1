
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
Function Get-Files {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'FileIDs'  )]
  # [OutputType([int[]])] # ToDo investigate OutputType if PassThru is true
  param(
    [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [Alias('Key')]
    [string] $hydrusSessionKey
    , [parameter(ParameterSetName = 'FileIDs', Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)]
    [Alias('FIDs')]
    [int[]] $FileIDs
    , [parameter(ParameterSetName = 'HashIDs', Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [Alias('HIDs')]
    [int[]] $HashIDs
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [Alias('DL')]
    [switch] $download
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [Alias('MD')]
    [switch] $metadata
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

    # assemblies needed to get exif data from an image
    Add-Type -TypeDefinition @'
    using System;
    using System.Drawing;
    using System.IO;
'@

    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    # requires system.IO.Path
    $originalPSBoundParameters = $PSBoundParameters # to allow debugging
    # ensure the function Get-ParameterValueFromNeoConfigurationRoot from the ATAP.Utilities.Powershell package is loaded
    # ToDo: require or import ATAP.Utilities.Powershell
    . $(Join-Path $([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities', 'src', 'ATAP.Utilities.PowerShell', 'public', 'Get-ParameterValueFromNeoConfigurationRoot.ps1')

    if ($hydrusSessionKey -or $FileIDs -or $HashIDs -or $download -or $metadata -or $hydrusAPIProtocol -or $hydrusAPIServer -or $hydrusAPIPort -or $PassThru -or $computerNames) {
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

    $downloadDirectory = Join-Path 'D:' 'temp'
    $getFilesPage = '/get_files/file'
    $getMetadataPage = '/get_files/file_metadata'
    $metadataSuffix = '.txt'

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    $script:headers = @{}
    $script:fileHash = ''
    $script:filename = ''


    function InternalGetOneFile {
      Write-PSFMessage -Level Debug -Message $("-FileIDs $FileIDs")

      $script:headers = @{'Hydrus-Client-API-Access-Key' = $HydrusSessionKey }
      switch ($PSCmdlet.ParameterSetName) {
        'FileIDs' { [void]$sb.Append('?file_id=' + $fileID ) }
        'HashIDs' { [void]$sb.Append('?hashs=' + $hashID ) }
        default { throw 'that ParameterSetName has not been implemented yet' }
      }
      if ($download) { [void]$sb.Append('&download=true') }
      $URI = [UriBuilder]::new($hydrusAPIProtocol, $hydrusAPIServer, $hydrusAPIPort, $getFilesPage, $sb.ToString())
      [void] $sb.Clear()
      # ToDo: wrap in a try-catch and a Polly-like wrapper, include timeout, etc.
      $response = Invoke-WebRequest -Uri $URI.uri -Headers $script:headers
      if ($response.Headers['Content-Disposition']) {
        # Extract the filename from the Content-Disposition header
        $contentDisposition = $response.Headers['Content-Disposition']
        $script:filename = [regex]::match($contentDisposition, 'filename="(.+)"') | ForEach-Object { $_.Groups[1].Value }
        if ($metadata) {
          # Taking advantage of the current hydrus software design that makes the file name and it's hash idempotent
          $script:fileHash = [System.IO.Path]::GetFileNameWithoutExtension($script:filename)
        }
        # only if download is true
        if ($download) {
          # Specify the local path to save the downloaded file
          $script:imageFileOutputPath = Join-Path $downloadDirectory $script:filename
          # ToDo: wrap in a try-catch and a Polly-like wrapper, include timeout, etc.
          $response = Invoke-WebRequest -Uri $URI.uri -Headers $script:headers -OutFile $script:imageFileOutputPath
        }
      }
      else {
        $message = 'the hydrusAPI response did not contain the Content-Disposition field, which is needed for the filename'
        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
    }

  }

  PROCESS {
    if ($noArgumentsSupplied) {
      # none of the cmdlets arguments have any values passed
      # possibly called from pipeline, either by property value, or just a standalone call expecting to use all default values
      # ToDo: implement batching
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
          elseif ($obj -is [int]) {
            # If obj is an integer, treat it as dirty, clean it, use it as a FileID
            # ToDo: Security: fix needed to test external input to the program/process space
            # ToDo: document in Powershell space, how the default int size can vary around, and why int32 was shosen for the v1 of any data intensive program
            # ToDo: security: this uses the internal integer parsing routines and error returns. Need to secure against exploits in underlying
            $FileId = [int32]::new($obj)
            InternalGetOneFile $obj
            if ($metadata) {
              InternalGetOneMetadata
            }

          }
          else {
            # deconstruct the pipeline object's properties
            $PropertyNames = $obj.PSobject.Properties.Name
            $hydrusSessionKey = $obj.PSobject.Properties['hydrusSessionKey']
            for ($PropertyNamesIndex = 0; $PropertyNamesIndex -lt $PropertyNames.Count; $PropertyNamesIndex++) {
              $PropertyName = $PropertyNames[$PropertyNamesIndex]
              switch ($PropertyName) {
                'hydrusSessionKey' { $hydrusSessionKey = $obj.PSobject.Properties['hydrusSessionKey'].value; break }
                'FileIDs' { $FileIDs = $obj.PSobject.Properties['FileIDs'].value; break }
                'HashIDs' { $HashIDs = $obj.PSobject.Properties['HashIDs'].value; break }
                'download' { $download = $obj.PSobject.Properties['download'].value; break }
                'hydrusAPIProtocol' { $hydrusAPIProtocol = $obj.PSobject.Properties['hydrusAPIProtocol'].value; break }
                'hydrusAPIServer' { $hydrusAPIServer = $obj.PSobject.Properties['hydrusAPIServer'].value; break }
                'hydrusAPIPort' { $hydrusAPIPort = $obj.PSobject.Properties['hydrusAPIPort'].value; break }
                'PassThru' { $PassThru = $obj.PSobject.Properties['PassThru'].value; break }
                'computerNames' { $computerNames = $obj.PSobject.Properties['computerNames'].value; break }
                default { # ignore any property names that are not parameters of this cmdlet}
                }
              }
            }
            # $FileIDs is an integer array, or it may be a singleton
            for ($FileIDsIndex = 0; $FileIDsIndex -lt $FileIDs.Count; $FileIDsIndex++) {
              $FileID = $FileIDs[$FileIDsIndex]
              InternalGetOneFile $FileID
              if ($metadata) {
                InternalGetOneMetadata
              }

            }
            # ToDo: accumulate any errors and add them to the pipeline object
            # If FileIDs or HashIDs passed as pipeline object parameters
            if ($PassThru) {
              # $result = @{
              #     HydrusSessionKey   = $hydrusSessionKey
              #     FileIDs           = $fileIDs
              #     HashIDs           = $hashIDs
              #     Download          = $download
              #     HydrusAPIProtocol = $hydrusAPIProtocol
              #     HydrusAPIServer   = $hydrusAPIServer
              #     HydrusAPIPort     = $hydrusAPIPort
              #     PassThru          = $passThru
              #     ComputerNames     = $computerNames
              #   }
              Write-Output $obj
            }
          }

        }
      }
      else {
        # not called from a pipeline, but no arguments are supplied. That is an error because the hydrusSessionKey has to be supplied, either from a command line argument or from an environment variable
        $message = 'the HydrusSessionKey is not supplied on the command line nor in the environment'
        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
    }
    else {
      # Not being used in a pipeline
      # $FileIDs is an integer array, or it may be a singleton
      for ($FileIDsIndex = 0; $FileIDsIndex -lt $FileIDs.Count; $FileIDsIndex++) {
        $FileID = $FileIDs[$FileIDsIndex]
        InternalGetOneFile $FileID
        if ($metadata) {
          InternalGetOneMetadata
        }

      }
      if ($PassThru) {
        # If FileIDs or HashIDs passed as argument
        $result = @{
          HydrusSessionKey   = $hydrusSessionKey
          FileIDs           = $fileIDs
          HashIDs           = $HashIDs
          Download          = $download
          HydrusAPIProtocol = $hydrusAPIProtocol
          HydrusAPIServer   = $hydrusAPIServer
          HydrusAPIPort     = $hydrusAPIPort
          PassThru          = $passThru
          ComputerNames     = $computerNames
        }
        Write-Output $result
      }
    }
  }

  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}
#############################################################################

