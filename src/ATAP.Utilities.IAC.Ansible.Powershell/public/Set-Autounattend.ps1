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
# parameter: autoUnattendTemplatePath
# parameter: templateLifecycleStage (default is [string] 'Production')
# parameter: autoUnattendDestinationPath
# parameter: modifications of type @{organizationName [string]; computerName [string]; WindowsBaseVersion [string];}
# parameter:# secrets: @{ WindowsProductKey [secureString]; HostsPath [string] }
.COMPONENT
The component this cmdlet belongs to
.ROLE
The role this cmdlet belongs to
.FUNCTIONALITY
This cmdlet creates a file named autoUnattend.xml, and writes that file to the $autoUnattendDestinationPath parameter location.
It reads the $autoUnattendTemplatePath and replaces placeholders there with data from a modifications structure.
#>
function Set-AutoUnattend {
  [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
    SupportsShouldProcess = $true,
    PositionalBinding = $false,
    ConfirmImpact = 'Medium')]
  [Alias()]
  [OutputType([Object])]
  Param (
    # ToDo: insert autoUnattendTemplatePath help description
    [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateScript({ Test-Path $_ })]
    [string] $autoUnattendTemplatePath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.IAC.Ansible\Resources\ATAP autounattend for utat022 win 11 Template.xml',
    # ToDo: insert autoUnattendDestinationPath help description
    [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    $autoUnattendDestinationPath,
    # ToDo: insert modifications help description
    [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    $modifications
  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $originalPSBoundParameters = $PSBoundParameters # to allow debugging
    # Parameter validation the input file exists
    # ToDo: output path validation

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    # Modify the selected template path with the lifecycle
    function ProcessBuffer {
      $substitutionPatterns = @()
      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
      $modificationsKeys = [System.Collections.ArrayList]($modifications.Keys)
      for ($modificationsIndex = 0; $modificationsIndex -lt $modificationsKeys.Count; $modificationsIndex++) {
        $modificationsKey = ('k' + $modificationsKeys[$modificationsIndex]).Replace('-', '')
        $modificationPattern = $modificationsKeys[$modificationsIndex]
        $substitutionPatterns += "(?<$modificationsKey>${modificationPattern})"
      }
      $substitutionPatternsString = $substitutionPatterns -join '|'
      # if ($pscmdlet.ShouldProcess("Target", "Operation")) {

      $script:inputObj
      # read the modifications structure for substitutionPatterns
      # ToDo: select the autoUnattend.xml template based on production, testing, or development
      $modifiedAutoUnattendTemplatePath = $autoUnattendTemplatePath
      # read the input file line by line, and accumulate them
      $FileStream = New-Object 'System.IO.FileStream' $modifiedAutoUnattendTemplatePath, 'Open', 'Read', 'ReadWrite'
      $reader = New-Object 'System.IO.StreamReader' $FileStream
      try {
        while (!$reader.EndOfStream) {
          $l = $reader.ReadLine()
          # search for all occurrences of the placeholders patterns (public and secret)
          $result = ([regex]::Matches($l, $substitutionPatternsString))[0]
          if ($result) {
            # loop over all the match groups (except 0) where success is true, each is a substitution to be made
            for ($MatchsIndex = 1; $MatchsIndex -le $result[0].groups.count; $MatchsIndex++) {
              $possibleMatch = $result[0].groups[$MatchsIndex]
              if ($possibleMatch.Success) {
                $l = $l -replace $possibleMatch.Value , $modifications[$possibleMatch.Value ]
              }
              # get the substutution text (or file) for the public placeholders from the modification's parameter
              # for the default parameterSetName
              # get the substutution text for the secret placeholders from the modification's parameter
              #$l -replace $Match , $modifications[$Match]
            }
          }
          # accumulate the lines for output
          $sb.AppendLine($l) > $null
        }

      } finally {
        $reader.Close()
        $FileStream.Close()
      }
      ####
      ####        # for the default parameterSetName
      ####        # get the substutution text for the secret placeholders from the modification's parameter
      ####        # for the Vault parameterSetName
      ####        # get the substutution text for the secret placeholders from the modification's Vault parameter
      # At this point the autoUnattend is ready to be written
      # write the accumulator to the autoUnattendDestinationPath
      # confirm that the autoUnattendDestinationPath exists and is writeable
      $sb.ToString() | Set-Content -LiteralPath $autoUnattendDestinationPath
    }
    ####    function Remote {
    ####      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    ####      $script:inputObj
    ####    }
    ####    function DispatchToBuffer {
    ####      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    ####      # Powershell implements short-circuiting for boolean operators
    ####      $typed = $$
    ####      if ($script:inputObj -is [string]) {
    ####        $typed = $true
    ####        # If obj is string, treat it as dirty, clean it, use it as a autoUnattendTemplatePath
    ####        # ToDo: Security: fix needed to test external input to the program/process space
    ####        # ToDo: security: make sure this obj can't be spoofed or used maliciously. Need to secure against exploits in underlying
    ####        $script:bufferOfautoUnattendTemplatePaths.Add($script:inputObj)
    ####      }
    ####      if ($(-not $typed) -and $($script:inputObj -is [System.IO.FileInfo])) {
    ####        $script:bufferOfAutoUnattendTemplatePaths.Add($script:inputObj.fullname)
    ####        $typed = $true
    ####      }
    ####      if ($typed) {
    ####        # If the buffer of autoUnattendTemplatePaths has reached the bufferSize limit, process all files in the buffer.
    ####        if ($script:bufferOfAutoUnattendTemplatePaths.count -ge $FileMetadatabufferSize ) {
    ####          Processbuffer
    ####        }
    ####      }
    ####      else {
    ####        if ($script:inputObj -is [string[]]) {
    ####          $typed = $true
    ####          for ($objIndex = 0; $objIndex -lt $script:inputObj.Count; $objIndex++) {
    ####            $script:bufferOfAutoUnattendTemplatePaths.Add($script:inputObj[$objIndex])
    ####            # If the buffer of autoUnattendTemplatePaths has reached the bufferSize limit, process all files in the buffer.
    ####            if ($script:bufferOfAutoUnattendTemplatePaths.count -ge $FileMetadatabufferSize ) {
    ####              Processbuffer
    ####            }
    ####          }
    ####        }
    ####        if (-not $typed -and $($script:inputObj -is [System.IO.FileInfo[]])) {
    ####          $typed = $true
    ####          for ($objIndex = 0; $objIndex -lt $script:inputObj.Count; $objIndex++) {
    ####            $script:bufferOfAutoUnattendTemplatePaths.Add($script:inputObj[$objIndex])
    ####            if ($script:bufferOfAutoUnattendTemplatePaths.count -ge $FileMetadatabufferSize ) {
    ####              Processbuffer
    ####            }
    ####          }
    ####        }
    ####      }
    ####      if (-not $typed) {
    ####        $message = "The argument is of type $($script:inputObj.gettype()) and is not supported. the argument must be a string or a fileinfo, an array of either, or a PSCustomObject/hashtable/.Net type having a autoUnattendTemplatePath property"
    ####        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
    ####        # toDo catch the errors, add to 'Problems'
    ####        Throw $message
    ####      }
    ####      $script:inputObj
    ####    }
  }

  PROCESS {
    # this cmdlet will accept pipeline input if it is in the form of an an object with the required properties, and it 'could' be run on another computer
    #    foreach ($script:inputObj in $input) {
    #      # This is pipeline processing, once around the loop for every input sent into this pipeline
    #      if ($script:inputObj.PSobject.Properties.Name -notcontains 'autoUnattendTemplatePath') {
    #        # $script:inputObj is not a PSCustomObject with a property named autoUnattendTemplatePath, so send it on to DispatchToBuffer for further type checking and processing
    #        DispatchToBuffer
    #      }
    #      else {
    #        # the input is a PSCustomObject with a property named autoUnattendTemplatePath
    #        # deconstruct the pipeline object's properties
    #        $PropertyNames = $script:inputObj.PSobject.Properties.Name
    #        for ($PropertyNamesIndex = 0; $PropertyNamesIndex -lt $PropertyNames.Count; $PropertyNamesIndex++) {
    #          $PropertyName = $PropertyNames[$PropertyNamesIndex]
    #          switch ($PropertyName) {
    #            'autoUnattendTemplatePath' { $autoUnattendTemplatePath = $script:inputObj.PSobject.Properties['autoUnattendTemplatePath'].value; break }
    #            'autoUnattendDestinationPath' { { $autoUnattendDestinationPath = $script:inputObj.PSobject.Properties['autoUnattendDestinationPath'].value; break } }
    #            'modifications' { { $modifications = $script:inputObj.PSobject.Properties['modifications'].value; break } }
    #            default {
    #              # ignore any property names that are not parameters of this cmdlet}
    #            }
    #          }
    #        }
    #        # DispatchToBuffer for further type checking and processing of the script:inputObj
    #        DispatchToBuffer
    #      }
    #      else {
    #        $message = 'No arguments on the command line and nothing supplied via pipeline'
    #        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
    #        # toDo catch the errors, add to 'Problems'
    #        Throw $message
    #      }
    #      else {
    #        # the $autoUnattendTemplatePath argument is not null
    #        # DispatchToBuffer for further type checking and processing of the script:inputObj
    #        DispatchToBuffer
    #      }
    #    }
    . ProcessBuffer
  }
  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}


