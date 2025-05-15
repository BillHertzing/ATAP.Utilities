<#
.SYNOPSIS
Short description
.DESCRIPTION
Long description
.EXAMPLE
Example of how to use this cmdlet
.EXAMPLE
Another example of how to use this cmdlet
.INPUTS
Inputs to this cmdlet (if any)
.OUTPUTS
Output from this cmdlet (if any)
.NOTES
General notes
.COMPONENT
The component this cmdlet belongs to
.ROLE
The role this cmdlet belongs to
.FUNCTIONALITY
The functionality that best describes this cmdlet
#>
function Get-ChatGPTResponseWithRAGContext {
  [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
    SupportsShouldProcess = $true,
    PositionalBinding = $false,
    ConfirmImpact = 'Medium')]
  [Alias()]
  [OutputType([Object])]
  Param (
    # ToDo: insert repoPath help description
    [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    $ParamName1
    # ToDo: insert ParamName2 help description
    , [Parameter(Mandatory = $false,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    $ParamName2
  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $originalPSBoundParameters = $PSBoundParameters # to allow debugging

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    function ProcessBufferLocallyGet-ChatGPTResponseWithRAGContext {
      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
      if ($pscmdlet.ShouldProcess("Target", "Operation")) {

        $script:inputObj
        # YOUR CODE HERE

      }

    }
    function ProcessBufferLocalGet-ChatGPTResponseWithRAGContext {
      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

      $script:inputObj

    }
    function RemoteGet-ChatGPTResponseWithRAGContext {
      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

      $script:inputObj

    }
    function DispatchToBufferGet-ChatGPTResponseWithRAGContext {
      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
      # Powershell implements short-circuiting for boolean operators
      $typed = $$
      if ($script:inputObj -is [string]) {
        $typed = $true
        # If obj is string, treat it as dirty, clean it, use it as a ParamName1
        # ToDo: Security: fix needed to test external input to the program/process space
        # ToDo: security: make sure this obj can't be spoofed or used maliciously. Need to secure against exploits in underlying
        $script:bufferOfParamName1s.Add($script:inputObj)
      }
      if ($(-not $typed) -and $($script:inputObj -is [System.IO.FileInfo])) {
        $script:bufferOfParamName1s.Add($script:inputObj.fullname)
        $typed = $true
      }
      if ($typed) {
        # If the buffer of ParamName1s has reached the bufferSize limit, process all files in the buffer.
        if ($script:bufferOfParamName1s.count -ge $FileMetadatabufferSize ) {
          Processbuffer
        }
      }
      else {
        if ($script:inputObj -is [string[]]) {
          $typed = $true
          for ($objIndex = 0; $objIndex -lt $script:inputObj.Count; $objIndex++) {
            $script:bufferOfParamName1s.Add($script:inputObj[$objIndex])
            # If the buffer of ParamName1s has reached the bufferSize limit, process all files in the buffer.
            if ($script:bufferOfParamName1s.count -ge $FileMetadatabufferSize ) {
              Processbuffer
            }
          }
        }
        if (-not $typed -and $($script:inputObj -is [System.IO.FileInfo[]])) {
          $typed = $true
          for ($objIndex = 0; $objIndex -lt $script:inputObj.Count; $objIndex++) {
            $script:bufferOfParamName1s.Add($script:inputObj[$objIndex])
            if ($script:bufferOfParamName1s.count -ge $FileMetadatabufferSize ) {
              Processbuffer
            }
          }
        }
      }
      if (-not $typed) {
        $message =
        The argument is of type $(script:inputObj.gettype()) and is not supported. the argument must be a string or a fileinfo, an array of either, or a PSCustomObject/hashtable/.Net type having a ParamName1 property

        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
      $script:inputObj
    }
  }

  PROCESS {
    foreach ($script:inputObj in $input) {
      if ($script:inputObj.PSobject.Properties.Name -notcontains 'ParamName1') {
        # $script:inputObj is not a PSCustomObject with a property named ParamName1, so send it on to DispatchToBuffer for further type checking and processing
        DispatchToBuffer
      }
      else {
        # the input is a PSCustomObject with a property named ParamName1
        # deconstruct the pipeline object's properties
        $PropertyNames = $script:inputObj.PSobject.Properties.Name
        for ($PropertyNamesIndex = 0; $PropertyNamesIndex -lt $PropertyNames.Count; $PropertyNamesIndex++) {
          $PropertyName = $PropertyNames[$PropertyNamesIndex]
          switch ($PropertyName) {
            'ParamName1' { $ParamName1 = $script:inputObj.PSobject.Properties['ParamName1'].value; break }
            default {
              # ignore any property names that are not parameters of this cmdlet}
            }
          }
        }
        # DispatchToBuffer for further type checking and processing of the script:inputObj
        DispatchToBuffer
      }
    }
  }
  else {
    $message = 'No arguments on the command line and nothing supplied via pipeline'
    Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
    # toDo catch the errors, add to 'Problems'
    Throw $message
  }
  else {
    # the $ParamName1 argument is not null
    # DispatchToBuffer for further type checking and processing of the script:inputObj
    DispatchToBuffer
  }
}

END {
  Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
}
}
