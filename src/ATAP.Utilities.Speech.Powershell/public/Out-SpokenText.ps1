
#############################################################################
#region Out-SpokenText (TextToSpeech, AKA TTS)
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
Function Out-SpokenText {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [alias('ToBeSpoken')]
    [parameter(
      Mandatory = $true
      , ValueFromPipeline = $true
      , ValueFromPipelineByPropertyName = $True
    )]
    [ValidateNotNullOrEmpty()]
    # TODO write script to validate the value of the parameter won't break the speech output subsystem
    $TextToSpeak
  )
  #endregion FunctionParameters

  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message "TextToSpeak = $TextToSpeak" -Tag 'SpeechGeneration', 'Speak'
    ########################################
    #region local private function
    function Private:TBD {
      [CmdletBinding(SupportsShouldProcess = $true)]
      param (
        $source
      )
      if ($source -is [string]) {
        Get-Item -Path $source
      }
      elseif ($source -is [System.IO.DirectoryInfo]) {
        Write-Warning "Copy-FileTimeAttributes  - Directories are not supported. Skipping $source."
        continue
      }
      elseif ($source -is [System.IO.FileInfo]) {
        $source
      }
      else {
        Write-Warning "Copy-FileTimeAttributes - Only files are supported. Skipping $source."
        continue
      }
    }

    function Private:TBD {
      [CmdletBinding(SupportsShouldProcess = $true)]
      param (
        $sourceFileInfo
        , $targetFileInfo
        , $Attributes
      )
      if ($sourceFileInfo.CreationTimeUtc -ne $targetFileInfo.CreationTimeUtc) {
        if ($PSCmdlet.ShouldProcess("Would copy CreationTimeUTC from $sourceFileInfo.fullname to $targetFileInfo.fullname")) {
          $sourceFileInfo.CreationTimeUtc = $targetFileInfo.CreationTimeUtc
        }
      }
      if ($sourceFileInfo.LastWriteTimeUtc -ne $targetFileInfo.LastWriteTimeUtc) {
        if ($PSCmdlet.ShouldProcess("Would copy LastWriteTimeUtc from $sourceFileInfo.fullname to $targetFileInfo.fullname")) {
          $sourceFileInfo.LastWriteTimeUtc = $targetFileInfo.LastWriteTimeUtc
        }
      }
    }
    #endregion local private function

  Add-Type -AssemblyName System.speech
  $tts = New-Object System.Speech.Synthesis.SpeechSynthesizer
  # $tts.SetOutputToDefaultAudioDevice()
  Write-PSFMessage -Level Debug -Message "Number of installed voices on this subsytem = $tts.GetInstalledVoices().count" -Tag 'SpeechGeneration', 'Configuration'
  #$voices = $tts.GetInstalledVoices()
$tts.Rate = 2

}
#endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    if ($PSCmdlet.ShouldProcess("Would output as speach the text $TextToSpeak")) {
    # $voice = $voices[1]
    # $tts.SelectVoice($voice)
    $tts.Speak($TextToSpeak)
  }
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    Write-PSFMessage -Level Debug -Message "Out-SpokenText was successfull" -Tag 'SpeechGeneration', 'Speak'
  }
  #endregion FunctionEndBlock
}
#endregion Out-SpokenText
#############################################################################

