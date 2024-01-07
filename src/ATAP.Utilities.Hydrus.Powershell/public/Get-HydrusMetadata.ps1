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
Function Get-HydrusMetadata {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern'  )]
  param(

    [Parameter(Mandatory = $false,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $false
    )]
    [Alias('MD')]
    # ToDo: replace with a c# type that holds all the fields expected in a image processing pipeline
    [PSCustomObject[]]$imageProcessingobject
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [switch] $PassThru
  )

  Begin {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $originalPSBoundParameters = $PSBoundParameters # to allow debugging
    $hydrusMetadatasuffix = '.txt'

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    $script:headers = @{}
    $script:fileHash = ''
    $script:filename = ''

    function InternalGetOneMetadata {
      Write-PSFMessage -Level Debug -Message $("fileHash $script:fileHash")
      $script:headers = @{'Hydrus-Client-API-Access-Key' = $HydrusSessionKey }
      switch ($PSCmdlet.ParameterSetName) {
        'FileIDs' { [void]$sb.Append('?file_id=' + $fileID ) }
        'HashIDs' { [void]$sb.Append('?hashs=' + $hashID ) }
        default { throw 'that ParameterSetName has not been implemented yet' }
      }
      if ($download) { [void]$sb.Append('&download=true') }
      $URI = [UriBuilder]::new($hydrusAPIProtocol, $hydrusAPIServer, $hydrusAPIPort, $getFilesPage, $sb.ToString())
      [void] $sb.Clear()

      # Get the Hydrus metadata
      [void] $sb.Append('?hashes=' + $(@(, $script:fileHash) | ConvertTo-Json -AsArray))
      $URI = [UriBuilder]::new($hydrusAPIProtocol, $hydrusAPIServer, $hydrusAPIPort, $getMetadataPage, $sb.ToString())
      [void] $sb.Clear()
      $script:metadataFileOutputPath = Join-Path $downloadDirectory $($script:fileHash + $metadataSuffix)
      # ToDo: wrap in a try-catch and a Polly-like wrapper, include timeout, etc.
      $response = Invoke-WebRequest -Uri $URI.uri -Headers $script:headers
      $metadata = $($response.content | convertfrom-json).metadata
      # Get the EXIF metadata

      # ToDo: implement batching
    }


    function LocalGetHydrusMetadata {
      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
      # Get the tags string from $script:obj
      # get the filename from $$script:obj and resolve it
      # replace the file suffix with the $hydrusMetadatasuffix  parameter
      if ($PassThru) {
        Write-Output $script:obj
      }


    }
    function InternalGetSidedcar {
      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
      LocalGetHydrusMetadata
    }
  }

  process {
    foreach ($script:obj in $metadataobject) {
      InternalGetSidedcar
    }
  }
}
