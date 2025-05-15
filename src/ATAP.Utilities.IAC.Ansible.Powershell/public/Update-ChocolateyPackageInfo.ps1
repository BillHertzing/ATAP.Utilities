Function Update-ChocolateyPackageInfo {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Files')]
  param (
    [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$chocolateyPackageInfoPath
    , [parameter(mandatory = $false, ParameterSetName = 'Files')]
    [string[]]$onHostPackagesPaths
    , [parameter(mandatory = $false, ParameterSetName = 'Hosts')]
    [string[]]$ComputerNames
  )
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    # Validate sourcePath, read it into an object
    $existingPackageInfo = Get-Content $chocolateyPackageInfoPath | ConvertFrom-Yaml
    $hostpackageInfos = @{}
  }
  Process {
    switch ($PSCmdlet.ParameterSetName) {
      Files {
        if (-not $PSBoundParameters.ContainsKey('onHostPackagesPaths')) {
          foreach ($chocolateyPackageInfoPath in $input) {
            $hostpackageInfos[$chocolateyPackageInfoPath] = Get-Content $chocolateyPackageInfoPath | ConvertFrom-Yaml
          }

        }
        else {
          foreach ($chocolateyPackageInfoPath in $onHostPackagesPaths) {
            $hostpackageInfos[$chocolateyPackageInfoPath] = Get-Content $chocolateyPackageInfoPath | ConvertFrom-Yaml
          }

        }
      }
      Computers {
        if (-not $PSBoundParameters.ContainsKey('ComputerNames')) {
          foreach ($computerName in $input) {
            $hostpackageInfos[$computerName] = Get-ChocolateyInstalledPackages -CN $computerName
          }

        }
        else {
          foreach ($computerName in $onHoComputerNamesstPackagesPaths) {
            $hostpackageInfos[$computerName] = Get-ChocolateyInstalledPackages -CN $computerName
          }

        }
      }
    }
    # loop over file names or computer names
  }
  END {
    # Overall Success is now $true
    $mergedPackageInfo = $existingPackageInfo
    $mergedPackageInfoKeys = [System.Collections.ArrayList]$($mergedPackageInfo.Keys)
    foreach ($key in $hostpackageInfos.keys){
      $packages = $hostpackageInfos[$key]
      foreach ($packageName in $packages.keys) {
        if (-not $mergedPackageInfoKeys.Contains($packageName)) {
          [Void]$mergedPackageInfoKeys.Add($packageName)
          $mergedPackageInfo[$packageName] = $packages[$packageName]
        }
      }
    }

    Write-PSFMessage -Level Important -Message $($mergedPackageInfo | ConvertTo-Yaml ) #| # Set-Content $chocolateyPackageInfoPath
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}
