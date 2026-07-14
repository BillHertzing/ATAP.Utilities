function Get-ParityWhitelistEntry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [object[]] $Whitelist,

    [Parameter(Mandatory = $true)]
    [string] $Category,

    [Parameter(Mandatory = $true)]
    [string] $Item,

    [Parameter(Mandatory = $true)]
    [string] $LeftHostName,

    [Parameter(Mandatory = $true)]
    [string] $LeftValue,

    [Parameter(Mandatory = $true)]
    [string] $RightHostName,

    [Parameter(Mandatory = $true)]
    [string] $RightValue
  )

  begin {
    $fn = 'Get-ParityWhitelistEntry'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Checking whitelist for '$Category/$Item'."
  }

  process {
    foreach ($entry in $Whitelist) {
      if ($entry.category -ne $Category -or $entry.item -ne $Item) {
        continue
      }

      $sourceHost = [string] $entry.sourceHost
      $targetHost = [string] $entry.targetHost
      $expectedOnSource = [string] $entry.expectedOnSource
      $acceptedOnTarget = [string] $entry.acceptedOnTarget

      $forwardMatch = $sourceHost -ieq $LeftHostName -and
        $targetHost -ieq $RightHostName -and
        $expectedOnSource -eq $LeftValue -and
        $acceptedOnTarget -eq $RightValue

      $reverseMatch = $sourceHost -ieq $RightHostName -and
        $targetHost -ieq $LeftHostName -and
        $expectedOnSource -eq $RightValue -and
        $acceptedOnTarget -eq $LeftValue

      if ($forwardMatch -or $reverseMatch) {
        return $entry
      }
    }
  }

  end {
  }
}
