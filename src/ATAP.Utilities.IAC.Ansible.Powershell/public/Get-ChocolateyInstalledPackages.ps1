function Get-ChocoInstalledPackages {
  [CmdletBinding()]
  param (
    [parameter(mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$path
    , [parameter(mandatory = $false, ParameterSetName = 'Files')]
    [string[]]$onHostPackagesPaths
    , [parameter(mandatory = $false, ParameterSetName = 'Computers')]
    [string[]]$ComputerNames
  )
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function Get-ChocoInstalledPackages' -Tag 'Get-ChocoInstalledPackages', 'Trace'

    #$excludeRegexPattern = '\.install$|^KB\d|^dotnet|^vcredist|^vscode-|^netfx-|^chocolatey-|^version$'
    $excludeRegexPattern = '\.install$'
    $packages = @{}

  }

  PROCESS {
    $lines = choco list --pre

    # throw away the first and the last line of the choco output
    for ($index = 1; $index -lt $lines.count - 1; $index++) {
      $validVersion = $null
      if ($lines[$index] -match '(\S+)\s+(.+)$') {
        if ([System.Version]::tryParse($matches[2], [REF] $validVersion)) {
          if ($matches[1] -notmatch $excludeRegexPattern) {
            $packages[$matches[1]] = @{Version = $validVersion; PreRelease = $false; AddedParameters = $null }
          }
          else { Write-PSFMessage -Level Error -Message "$($matches[1]) matched the excludeRegexPattern. Line number $index was $($lines[$index])" }
        }
        else { Write-PSFMessage -Level Error -Message "$($matches[2]) did not parse as a [System.Version]. Line number $index was $($lines[$index])" }
      }
      else { Write-PSFMessage -Level Error -Message "$lines[$index] did not match the pattern '(\S+)\s+(.+)$. Line number $index was $($lines[$index])" }
    }
  }

  END {
    $packages
  }
}
