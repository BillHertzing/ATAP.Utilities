#############################################################################
#region New-EncryptionKeyPassPhraseFile
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
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
[Powershell: Shuffle-words / Generate Random words / Mix words Puzzle](https://docs.microsoft.com/en-us/answers/questions/397819/powershell-shuffle-words-generate-random-words-mix.html) Answer by Andreas Baumgarten
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function New-EncryptionKeyPassPhraseFile {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet')]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $(Split-Path $_) -PathType 'Container' })]
    [string] $PassPhrasePath
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Encoding
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    #$DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    # ToDo: Put a much larger word list in the database and extract 100 possible words form the DB
    # Word list
    $words = @(
      'rabbit', 'peccary', 'colt', 'anteater',
      'meerkat', 'eagle', 'owl', 'cow', 'turtle', 'bull',
      'baselisk', 'snake', 'lizzard', 'panda', 'bear', 'pig',
      'lion', 'tiger', 'bunny', 'wolf', 'deer', 'pronghorn',
      'fish', 'rabbit', 'gorilla', 'puma', 'mustang', 'sheep',
      'wolverine', 'hyena', 'beaver', 'rooster', 'ox', 'frog'
    )
    $randomwords = @();
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    # get 10 random words
    1..10 | % { $randomwords += Get-Random -InputObject $words }
    $randomwords | Out-File -Encoding $Encoding -FilePath $PassPhrasePath
    Write-PSFMessage -Level Debug -Message "RandomWords = $( $randomwords -join ' ')"
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion New-EncryptionKeyPassPhraseFile
#############################################################################
