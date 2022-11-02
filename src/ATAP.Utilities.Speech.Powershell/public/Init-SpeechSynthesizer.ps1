
#############################################################################
#region Init-SpeecSynthesizer (TextToSpeech, AKA TTS)
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
An initialized speech synthesizer
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
Function Init-SpeechSynthesizer {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
  # ToDo: add configurable parameters
    [parameter(
      Mandatory = $false
      , ValueFromPipeline = $false
      , ValueFromPipelineByPropertyName = $True
    )]
    # [ValidateNotNullOrEmpty()]
    # TODO write script to validate the value of the parameter won't break the speech output subsystem
    $Rate
  )
  #endregion FunctionParameters

    Write-PSFMessage -Level Debug -Message "Init-SpeechSynthesizer " -Tag 'SpeechGeneration', 'Init'
    ########################################
    #region local private functionss
    #endregion local private function

  Add-Type -AssemblyName System.speech
  $tts = New-Object System.Speech.Synthesis.SpeechSynthesizer
  # $tts.SetOutputToDefaultAudioDevice()
  Write-PSFMessage -Level Debug -Message "Number of installed voices on this subsytem = $tts.GetInstalledVoices().count" -Tag 'SpeechGeneration', 'Configuration'
  #$voices = $tts.GetInstalledVoices()
  $tts.Rate = 2

    Write-PSFMessage -Level Debug -Message "Init-SpeechSynthesizer was successfull" -Tag 'SpeechGeneration', 'Init'
	# return the initialized SpeechSynthesis object
	$tts
}
#endregion Init-SpeecSynthesizer
#############################################################################

