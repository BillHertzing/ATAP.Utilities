# Return a DSC configuration file contents for a WebServer
param(
    [string] $ymlGenericTemplate
  , [string] $directoryPath
  , [string] $dSCConfigurationName
  , [string] $dSCConfigurationFilename
  , [string] $dSCConfigurationSourcePath
)

function Contents {

  return @"
  Configuration WebServerConfiguration
  {
      Import-DscResource -ModuleName PSDesiredStateConfiguration

      Node localhost
      {
          WindowsFeature IIS
          {
              Name = "Web-Server"
              Ensure = "Present"
          }
      }
  }
"@
}

Set-Content -Path $dSCConfigurationSourcePath -Value Contents

