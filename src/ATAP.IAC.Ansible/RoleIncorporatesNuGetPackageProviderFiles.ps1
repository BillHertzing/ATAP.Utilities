# Return a DSC configuration file contents for a WebServer
param(
    [string] $ymlGenericTemplate
  , [string] $directoryPath
  , [string] $dSCConfigurationName
  , [string] $dSCConfigurationFilename
  , [string] $dSCConfigurationWindowsSourcePath
)

function Contents {
  return @"
  Configuration $dSCConfigurationName
  {
      Import-DscResource -ModuleName PSDesiredStateConfiguration

      Node localhost
      {
        Import-DscResource -Module cChoco
        Node "localhost"
        {
           cChocoInstaller installChoco
           {
             InstallDir = 'C:/temp/chocotesting'
           }
        }
  }

"@
}

$ymlContents = $ymlGenericTemplate
$ymlContents += Contents
Set-Content -Path $dSCConfigurationWindowsSourcePath -Value $ymlContents

