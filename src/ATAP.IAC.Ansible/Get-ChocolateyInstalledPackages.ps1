function Get-ChocoInstalledPackages {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Files')]
  param (
    [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$path
    , [parameter(mandatory = $false, ParameterSetName = 'Files')]
    [string[]]$onHostPackagesPaths
    , [parameter(mandatory = $false, ParameterSetName = 'Computers')]
    [string[]]$ComputerNames
  )
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

    #$excludeRegexPattern = '\.install$|^KB\d|^dotnet|^vcredist|^vscode-|^netfx-|^chocolatey-|^version$'
    $excludeRegexPattern = '\.install$'
    $packages = @{}
    
  }

  PROCESS {
    # --lo is removed in chocolatey V2.0 +
    $lines = choco list --lo --pre

    # throw away the first and the last line of the choco output
    for ($index = 1; $index -lt $lines.count - 1; $index++) {
      $validVersion = $null
      if ($lines[$index] -match '(\S+)\s+(.+)$') {
        if ([System.Version]::tryParse($matches[2], [REF] $validVersion)) {
          if ($matches[1] -notmatch $excludeRegexPattern) {
            $packages[$matches[1]] = @{Version = $validVersion; PreRelease = $false; AddedParameters = $null }
          }
          else {Write-PSFMessage -Level Error -Message "$($matches[1]) matched the excludeRegexPattern. Line number $index was $($lines[$index])" }
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
