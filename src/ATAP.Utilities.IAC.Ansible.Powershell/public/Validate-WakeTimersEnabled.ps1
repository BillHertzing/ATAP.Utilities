# Not working, I'm currently unable to discover how to read the actual wake on timer setting for a power plan.
# This is a work in progress, but I am leaving it here for now.
# This function is intended to validate the wake timers setting for each power plan.
# It will return a hashtable with the power plan name as the key and a boolean value
# indicating whether wake timers are enabled (true) or disabled (false).
# If the power plan does not have a wake timers setting, it will return 'Default'
# as the value for that power plan.
# If the power plan has an unexpected value, it will return 'Unexpected! <value>'
# This should also record if the Default is on or off
# the AC and DC settings for the power plan are complicating things.
# but this command powercfg /q seems to show that the default is 'on' for AC and 'off' for DC.

function Validate-WakeTimersEnabled {
  [CmdletBinding()]
  param (
  )

  Begin {
    Write-PSFMessage -Level Verbose -Message 'Entering function: Validate-WakeTimersEnabled' -Tag 'Validate-WakeTimersEnabled', 'Trace'
    $allowWake = $false
    $allowWakeTimersPerPowerPlan = @{}
    # ToDo: Move constant to a global variable
    $powerSchemesPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes'
    $sleepSubgroupGUID = '238C9FA8-0AAD-41ED-83F4-97BE242C8F20'
    $allowWakeTimersGUID = 'BD3B718A-0680-4D9D-8AB2-E1D2B4AC806D'
    $acDcSubgroupGUID = '245d8541-3943-4422-b025-13a784f679b7'
    # Default Wake Timers setting
    $pathForDefaultValueOfWakeTimers = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$sleepSubgroupGUID\$allowWakeTimersGUID"
    # Test that the subkey or property exists
    if (-not (Test-Path -Path $pathForDefaultValueOfWakeTimers)) {
      $errormessage = "Power plan default wake timers setting not found at: $pathForDefaultWakeTimers"
      Write-PSFMessage -Level Error         -Message $ErrorMEssage        -Tag 'Validate-WakeTimersEnabled', 'Trace'
      throw $errormessage
    }
    # you can get the allowable values for wakeOnSleep from "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$sleepSubgroupGUID\$allowWakeTimersGUID"
    # That only tells you what the possible values can be, not what the actual default 'allowWakeTimers' IS/
    $defaultWakeTimerValue = Get-ItemProperty -Path $pathForDefaultValueOfWakeTimers
    $allowWakeTimersPerPowerPlan.add('Default', $defaultWakeTimerValue)

    # get all available powerPlanGUIDs
    $powerPlanGUIDs = (Get-ChildItem -Path $powerSchemesPath).PSChildName
  }

  Process {
    # True  = wake-timers allowed
    # False = wake-timers disabled
    foreach ( $powerPlanGUID in $powerPlanGUIDs ) {
      $name = (((Get-ItemProperty -Path "$powerSchemesPath\$powerPlanGUID" `
              -ErrorAction SilentlyContinue).FriendlyName) -split ',')[2]
      $regpath = "$powerSchemesPath\$powerPlanGUID\$sleepSubgroupGUID\$allowWakeTimersGUID"
      # Test if the subkey exists
      if (-not (Test-Path -Path $regpath)) {
        Write-PSFMessage -Level Warning `
          -Message "Power plan $name ($powerPlanGUID) does not have a wake timers setting." `
          -Tag 'Validate-WakeTimersEnabled', 'Trace'
        #
        $allowWakeTimersPerPowerPlan.add($name, 'Default')
        continue
      }
      $allowWakeTimer = Get-ItemProperty -Path "$regpath" -ErrorAction SilentlyContinue
      switch ($allowWakeTimer) {
        0 { $allowWakeTimersPerPowerPlan.add($name, $false) }
        1 { $allowWakeTimersPerPowerPlan.add($name, $true) }
        default {
          Write-PSFMessage -Level Warning `
            -Message "Unexpected value for wake timers setting in power plan: $name ($powerPlanGUID). Value: $($allowWakeTimer.$(Get-ItemProperty -Path $regpath).PSChildName)" `
            -Tag 'Validate-WakeTimersEnabled', 'Trace'
          allowWakeTimersPerPowerPlan.add($name, "Unexpected! $allowWakeTimer")
        }
      }
    }
  }

  End {

    Write-PSFMessage -Level Verbose -Message 'Leaving function: Validate-WakeTimersEnabled' -Tag 'Validate-WakeTimersEnabled', 'Trace'

    Return $allowWakeTimersPerPowerPlan
  }
}
