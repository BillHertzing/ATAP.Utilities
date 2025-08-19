
function Get-PathDirectoriesListing {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (

  )

  $results = @{PathDoesNotExist : @(); PathHasNoExes : @() }

  $paths = $env:PATH -split [IO.Path]::PathSeparator
  $PathDoesNotExist = @()
  $PathHasNoExes = @()
  $paths | % { $path = $_
    # ToDo: Implement tests and accumulate results
    $path
  }
}

