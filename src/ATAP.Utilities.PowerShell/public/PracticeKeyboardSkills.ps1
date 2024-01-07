#############################################################################
#region PracticeKeyboardSkills
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
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
function PracticeKeyboardSkills {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [alias('ResponseTimeLimit')]
    [parameter(
      Mandatory = $false
      , ValueFromPipeline = $false
      , ValueFromPipelineByPropertyName = $True
    )]
    # TODO write script to validate the value of the parameter won't break the speech output subsystem
    $inputStreamMonitorPeriodInSecs
    , [parameter(
      Mandatory = $false
      , ValueFromPipeline = $false
      , ValueFromPipelineByPropertyName = $True
    )]
    [ValidateSet('COMMON', 'ECO1', 'ECO2', 'MIL1', 'MIL2', 'All')]
    [string[]]$keyMaps
    , [parameter(
      Mandatory = $false
      , ValueFromPipeline = $false
      , ValueFromPipelineByPropertyName = $True
    )]
    [char] $quitKey
  )
  Write-PSFMessage -Level Debug -Message 'PracticeKeyboardSkills' -Tag 'PracticeKeyboardSkills', 'Startup'
  # validate the necessary ps modules are available, load them
  # . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Speech.Powershell\public\Out-SpokenText.ps1'
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Speech.Powershell\public\Init-SpeechSynthesizer.ps1'
  # load configuration settings
  # ToDo put these into a configuration file

  # What voice to use
  # what pitch to use
  # how quickly to speak

  # how long to monitor the input stream after a phrase is finished
  if (-not ($PSBoundParameters.ContainsKey('inputStreamMonitorPeriodInSecs'))) {
    $inputStreamMonitorPeriodInSecs = 2
  }
  # which set of profiles to allow
  if (-not ($PSBoundParameters.ContainsKey('keyMaps'))) {
    $keyMaps = @('ALL')
  }
  # which keystroke will quit the practice
  if (-not ($PSBoundParameters.ContainsKey('quitKey'))) {
    # a Keystroke that will end the program, ESC by default
    $quitKey = 0X1B # the ESC key's VirtualKeyCode
  }

  Write-PSFMessage -Message "inputStreamMonitorPeriodInSecs is $inputStreamMonitorPeriodInSecs" -Level Debug
  Write-PSFMessage -Message "keyMaps is $keyMaps" -Level Important
  Write-PSFMessage -Message "quitKey is $($([byte]$quitKey).ToString())" -Level Important

  # A pattern that matches the set of allowed keymaps
  $allowedKeyMapsPattern = if ($keymaps -eq 'all') { @('COMMON', 'ECO1', 'ECO2', 'MIL1', 'MIL2', 'All') -join '|' } else { $keymaps -join '|' }
  Write-PSFMessage -Message "allowedKeyMapsPattern is $allowedKeyMapsPattern" -Level Debug
  # How often the check the input stream for another keypress
  $inputStreamMonitorResolutionInMilliSecs = 250
  # ToDo: How long between the end of the monitoring period and starting the next speakphrase-monitorinput

  # the persistent storage information for saving practice runs and their results
  $practiceRunResults = [System.Collections.ArrayList]::new()

  # How to display the results of a practice run
  # how to display the practice run results over a period of time

  # The persistent storage location where to find the phrases to speak and their expected result
  $phraseAndExpectedKeyCodesStorage = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Speech.Powershell\public\AOE IV Keyboad shortcuts practice phrases.ps1'
  # ToDo: The pattern used to identify comments in the list of phrases to speak
  # ToDo: may be used in the future when the input objects come from a stream $commentPattern = '^\s*#'

  # Private event handlers

  # Handle the speech synthethesis events
  # Start speaking event handler
  # End speaking event handler

  # Handle the timer events

  # set the state to initialize practice run
  # initialize the speech synthesizer
  $tts = Init-SpeechSynthesizer
  # initialize the event handlers' sub-states
  # attach the event handlers to the speach synthesizer

  # calculate how many times to check input stream
  $maxNumberOfTimesToCheckInputStream = ($inputStreamMonitorPeriodInSecs * 1000) / $inputStreamMonitorResolutionInMilliSecs

  # initialize the data structures for expected and actual results
  $actualKeyCodes = [System.Collections.ArrayList]::new()
  $expectedKeyCodes = [System.Collections.ArrayList]::new()

  # initialize the persistent output storage for this invocation of the program
  #  filesystem: No initialization needed
  #  open a file for the results
  #  add current date/time of start, and  ...


  # set the state to start practice run
  $state = 'StartPracticeRun'
  # create a randomized set of phrases and their expected results from the input persistent storage location
  $randomPhraseAndExpectedKeyCodes = . $phraseAndExpectedKeyCodesStorage | Where-Object { $_.Keymap -match $allowedKeyMapsPattern } | Get-Random -Shuffle

  # While more phrases exist
  for ($phraseIndex = 0; $phraseIndex -lt $randomPhraseAndExpectedKeyCodes.count; $phraseIndex++) {
    Write-PSFMessage -Level Debug -Message "Phrase = $phrase" -Tag 'PracticeKeyboardSkills', 'IndividualPhrase'

    # fetch the phrase
    $phrase = $randomPhraseAndExpectedKeyCodes[$phraseIndex].Phrase
    Write-PSFMessage -Message "Phrase number $phraseIndex ""$phrase""" -Level Important
    # Set the sub-state to SpeechStarting
    # speak phrase
    $tts.speak($phrase)
    # wait on the phrase to be spoken (wait on the sub-state to become 'SpeechFinished')
    # clear the input queue (see Powershell issue #959, https://github.com/PowerShell/PSReadLine/issues/959)
    Start-Sleep -Milliseconds 100;
    $host.ui.RawUI.FlushInputBuffer();
    # monitor the input queue, along with a timeout
    # https://stackoverflow.com/questions/150161/waiting-for-user-input-with-a-timeout  answer by Elavarasan Muthuvalavan - Lee's user avatar
    # modified by https://rosettacode.org/wiki/Keyboard_input/Flush_the_keyboard_buffer#PowerShell
    $numberOfTimesChecked = 0
    while ($numberOfTimesChecked -le $maxNumberOfTimesToCheckInputStream) {
      while ($host.UI.RawUI.KeyAvailable) {
        $key = $host.ui.RawUI.ReadKey('NoEcho,IncludeKeyUp')
        if ($key.VirtualKeyCode -eq $quitKey) {
          #For Key Combination: eg., press 'LeftCtrl + q' to quit.
          #Use condition: (($key.VirtualKeyCode -eq $Qkey) -and ($key.ControlKeyState -match "LeftCtrlPressed"))
          break
        }
        # accept input into an arraylist until monitoring period expires
        $actualKeyCodes.Add($key) >$null
      }
      $numberOfTimesChecked = $numberOfTimesChecked + 1
      Write-PSFMessage -Level Debug -Message "Number of times checking the input stream is now $numberOfTimesChecked" -Tag 'PracticeKeyboardSkills', 'MonitorInput'
      Start-Sleep -m $inputStreamMonitorResolutionInMilliSecs
    }

    # Analyze the actual results (an array of KeyInfo type instances)
    # if the array is enmpty, it is an error, no input inside of the 'TimeToMonitor" window
    if ($actualKeyCodes.count -eq 0) {
      Write-PSFMessage -Message "Phrase number $phraseIndex ""$phrase"" Incorrect, no input received within $inputStreamMonitorPeriodInSecs seconds" -Level Important
    }
    else {
      # hack: throw out the first element if it is a carriage return (see Powershell issue #959, https://github.com/PowerShell/PSReadLine/issues/959)
      if ($actualKeyCodes[0].VirtualKeyCode -eq 13) {
        $hackedActualKeyCodes = $actualKeyCodes[1..($actualKeyCodes.count - 1)]
      }
      else {
        $hackedActualKeyCodes = $actualKeyCodes
      }
      # extract any modifier keys (ControlKey state values)
      # extract any navigation keys
      # extract any function keys
      # map the remaining characters to their uppercase equivalent VirtualKeyCode
      $actualVirtualKeyCodes = $hackedActualKeyCodes.VirtualKeyCode

      # fetch the expected results and convert all to uppercase
      $expectedKeyCodesString = $randomPhraseAndExpectedKeyCodes[$phraseIndex].ExpectedResult.ToUpper()
      $expectedKeyCodesBytes = $expectedKeyCodesString.ToCharArray()
      # Convert to an array of KeyInfo type instances
      for ($keyCodesIndex = 0; $keyCodesIndex -lt $expectedKeyCodesBytes.count; $keyCodesIndex++) {
        switch -regex ($expectedKeyCodesString[$keyCodesIndex]) {
          '[A-Za-z0-9]' {
            $expectedKeyCodes.Add([System.Management.Automation.Host.KeyInfo]::new([int][char]$expectedKeyCodesBytes[$keyCodesIndex], [char]$($([string]$expectedKeyCodesBytes[$keyCodesIndex]).ToLower()), 0, $false))>$null
          }
          '\/' { $expectedKeyCodes.Add([System.Management.Automation.Host.KeyInfo]::new(191, [char]'/', 0, $false))>$null }
          '\.' { $expectedKeyCodes.Add([System.Management.Automation.Host.KeyInfo]::new(190, [char]'.', 0, $false))>$null }
          '\,' { $expectedKeyCodes.Add([System.Management.Automation.Host.KeyInfo]::new(188, [char]',', 0, $false))>$null }
          "'" { $expectedKeyCodes.Add([System.Management.Automation.Host.KeyInfo]::new(222, [char]"'", 0, $false))>$null }
        }
      }
      # extract any modifier keys.
      # Enumeration values are (ShiftPressed,NumLockOn, ScrollLockOn, CapsLockOn, LeftCtrlPressed, RightCtrlPressed, EnhancedKey , LeftAltPressed, RightAltPressed)
      # Values in the Expected Value field also add (case-insensitive) CTRL-, Shift-, Alt-
      # Ctrl, Shift, and Alt
      # extract any navigation keys
      # extract any function keys
      # map the remaining characters to their uppercase equivalent VirtualKeyCode
      #$expectedKeyCodes = [int[]][char[]]$expectedKeyCodes.ToUpper()

      # update the persistent storage with the latest speakphrase-monitorinput results
      # ToDo: enhance to handle modifiers, navigation, and function keys
      if (Compare-Object $hackedActualKeyCodes $expectedKeyCodes) {
        Write-PSFMessage -Message "Incorrect, expected $expectedKeyCodes, got  $hackedActualKeyCodes" -Level Important
      }
      else {
        Write-PSFMessage -Message 'Correct' -Level Important
      }

    }
    # Clear the results
    $actualKeyCodes.Clear()
    $expectedKeyCodes.Clear()

  }
  # end loop

  # dispose of the speech synthesizer
  $tts.dispose()
  # dispose of the monitor timer

  # save this latest practice run results to persistent storage
  # Display this practice run results and historical progression
  # ask for user acknowlegement





}
#endregion PracticeKeyboardSkills
#############################################################################
