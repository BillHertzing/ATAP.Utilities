#
# Get-PathDirectoriesListing.ps1
#
[CmdletBinding(SupportsShouldProcess=$true)]
param (

)

function Get-PathDirectoriesListing {
[CmdletBinding(SupportsShouldProcess=$true)]
param (

)

    $paths=  $env:PATH -split [IO.Path]::PathSeparator
    $PathDoesNotExist = @()
    $PathHasNoExes = @()
    $paths | %{$path = $_
      # ToDo: Implement tests and accumulate results
        $path
    }
}

Get-PathDirectoriesListing
