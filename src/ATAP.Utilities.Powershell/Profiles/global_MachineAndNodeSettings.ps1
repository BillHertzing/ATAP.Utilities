
# $DropBoxBasePathConfigRootDefault = ''
# $FastTempPathConfigRootDefault = ''
# $PlantUmlClassDiagramGeneratorPathConfigRootKey = 'PlantUmlClassDiagramGeneratorPath'
# $GitExeConfigRootKey = 'GitPath'
# $GitExeConfigRootDefault = ''
$PathToProjectOrSolutionFilePattern = '(.*)\.(sln|csproj)'

#$global:RequiredMachineSettingsList = @($global:configRootKeys['CloudBasePathConfigRootKey'], $global:configRootKeys['FastTempPathConfigRootKey'])

# $global:SupportedJenkinsRolesList = @($global:configRootKeys['WindowsDocumentationBuildConfigRootKey'], $global:configRootKeys['WindowsCodeBuildConfigRootKey'], $global:configRootKeys['WindowsUnitTestConfigRootKey'], $global:configRootKeys['WindowsIntegrationTestConfigRootKey'])

$global:WindowsUnitTestList = @('Run-WindowsUnitTests')

$global:WindowsUnitTestArgumentsList = @('PathToProjectOrSolutionFilePattern', 'PathToTestLog')

# only set the value of the Environment Environment variable if it has not been set by a calling process
$inheritedEnvironmentVariable = [System.Environment]::GetEnvironmentVariable('Environment')
$inProcessEnvironmentVariable = ''
if ($inheritedEnvironmentVariable) {
  $inProcessEnvironmentVariable = $inheritedEnvironmentVariable
}
else {
  $inProcessEnvironmentVariable = 'Production' # default for all machines is Production, can be overwritten on a per-process basis if needed
}

$local:MachineAndNodeSettings = @{

  # Settings common to all machines

  # The location where Chocolatey installs some packages and some programs
  $global:configRootKeys['ChocolateyLibDirConfigRootKey']                                                                = Join-Path $env:ProgramData 'chocolatey' 'lib'
  $global:configRootKeys['ChocolateyBinDirConfigRootKey']                                                                = Join-Path $env:ProgramData 'chocolatey' 'bin'

  # These values are specific to the way an organization defines and sets up the access to and use of 3rd party applications
  $global:configRootKeys['MSBuildExePathConfigRootKey']                                                                  = Join-Path $env:ProgramFiles 'Microsoft Visual Studio' '2022' 'Community' 'Msbuild' 'Current' 'Bin' 'MSBuild.exe'
  $global:configRootKeys['DotnetExePathConfigRootKey']                                                                   = Join-Path $env:ProgramFiles 'dotnet' 'dotnet.exe'
  $global:configRootKeys['DocFXExePathConfigRootKey']                                                                    = Join-Path $env:ProgramData 'chocolatey' 'bin' 'docfx.exe'
  $global:configRootKeys['GraphvizExePathConfigRootKey']                                                                 = Join-Path $env:ProgramFiles 'graphviz' 'bin' 'dot.exe'
  $global:configRootKeys['CommonJarsBasePathConfigRootKey']                                                              = Join-Path $env:ProgramData 'CommonJars'

  # Jenkins CI/CD confguration keys
  # These used to access a Jenkins Controller and Authenticate

  $global:configRootKeys['JENKINS_URLConfigRootKey']                                                                     = 'http://utat022:4040/'
  $global:configRootKeys['JENKINS_USER_IDConfigRootKey']                                                                 = 'whertzing'
  $global:configRootKeys['JENKINS_API_TOKENConfigRootKey']                                                               = '117e33cc37af54e0b4fc6cb05de92b3553' # the value from the configuration page ToDo: use Secrets GUID/file

  # The repository names by which each of the various repositories for Powershell packages are known; NuGet, Chocolatey, PowershellGet
  # Package Repository Source locations
  #ToDo: add code throughout that recognizes a "cluster" of containers that have the same root path for shared filesystems paths, typically a group of machines in a geolocation having fast access to this netowro resource, for example a cluster of machines used in a CI/CD pipeline
  $global:configRootKeys['RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey']                        = '\\utat022\fs'
  # Common Filesystem root path for all machines in a cluster that has this root path
  # Package Repository Source location NuGet
  $global:configRootKeys['RepositoryNuGetFilesystemDevelopmentPackageNameConfigRootKey']                                 = 'ReposistoryNuGetFilesystemDevelopmentPackage'
  $global:configRootKeys['RepositoryNuGetFilesystemDevelopmentPackagePathConfigRootKey']                                 = 'Join-Path $global:settings[$global:configRootKeys["RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey"]] "NuGet" "Development"'
  $global:configRootKeys['RepositoryNuGetFilesystemQualityAssurancePackageNameConfigRootKey']                            = 'RepositoryNuGetFilesystemQualityAssurancePackage'
  $global:configRootKeys['RepositoryNuGetFilesystemQualityAssurancePackagePathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey"]] "NuGet" "QualityAssurance"'
  $global:configRootKeys['RepositoryNuGetFilesystemProductionPackageNameConfigRootKey']                                  = 'RepositoryNuGetFilesystemProductionPackage'
  $global:configRootKeys['RepositoryNuGetFilesystemProductionPackagePathConfigRootKey']                                  = 'Join-Path $global:settings[$global:configRootKeys["RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey"]] "NuGet" "Production"'

  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageProtocolConfigRootKey']              = 'http'
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey']         = 'http'
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerProductionPackageProtocolConfigRootKey']               = 'http'
  $global:configRootKeys['RepositoryNuGetProductionWebServerDevelopmentPackageProtocolConfigRootKey']                    = 'http'
  $global:configRootKeys['RepositoryNuGetProductionWebServerQualityAssurancePackageProtocolConfigRootKey']               = 'http'
  $global:configRootKeys['RepositoryNuGetProductionWebServerProductionPackageProtocolConfigRootKey']                     = 'http'
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageServerConfigRootKey']                = 'utat022'
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey']           = 'utat022'
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerProductionPackageServerConfigRootKey']                 = 'utat022'
  $global:configRootKeys['RepositoryNuGetProductionWebServerDevelopmentPackageServerConfigRootKey']                      = 'utat022'
  $global:configRootKeys['RepositoryNuGetProductionWebServerQualityAssurancePackageServerConfigRootKey']                 = 'utat022'
  $global:configRootKeys['RepositoryNuGetProductionWebServerProductionPackageServerConfigRootKey']                       = 'utat022'
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerDevelopmentPackagePortConfigRootKey']                  = '1112'
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey']             = '1111'
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerProductionPackagePortConfigRootKey']                   = '1110'
  $global:configRootKeys['RepositoryNuGetProductionWebServerDevelopmentPackagePortConfigRootKey']                        = '1102'
  $global:configRootKeys['RepositoryNuGetProductionWebServerQualityAssurancePackagePortConfigRootKey']                   = '1101'
  $global:configRootKeys['RepositoryNuGetProductionWebServerProductionPackagePortConfigRootKey']                         = '1100'

  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageURIConfigRootKey']                   = @'
  [UriBuilder]::new(
  $($global:settings[$global:configRootKeys["RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageProtocolConfigRootKey"]]),
  $($global:settings[$global:configRootKeys["RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageServerConfigRootKey"]]),
  $($global:settings[$global:configRootKeys["RepositoryNuGetQualityAssuranceWebServerDevelopmentPackagePortConfigRootKey"]]),"Development").ToString()
'@
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey']              = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey"]]),"QualityAssurance").ToString()
'@
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerProductionPackageURIConfigRootKey']                    = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryNuGetQualityAssuranceWebServerProductionPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryNuGetQualityAssuranceWebServerProductionPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryNuGetQualityAssuranceWebServerProductionPackagePortConfigRootKey"]]),"Production").ToString()
'@
  $global:configRootKeys['RepositoryNuGetProductionWebServerDevelopmentPackageURIConfigRootKey']                         = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryNuGetProductionWebServerDevelopmentPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryNuGetProductionWebServerDevelopmentPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryNuGetProductionWebServerDevelopmentPackagePortConfigRootKey"]]),"Development").ToString()
'@
  $global:configRootKeys['RepositoryNuGetProductionWebServerQualityAssurancePackageURIConfigRootKey']                    = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryNuGetProductionWebServerQualityAssurancePackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryNuGetProductionWebServerQualityAssurancePackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryNuGetProductionWebServerQualityAssurancePackagePortConfigRootKey"]]),"QualityAssurance").ToString()
'@
  $global:configRootKeys['RepositoryNuGetProductionWebServerProductionPackageURIConfigRootKey']                          = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryNuGetProductionWebServerProductionPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryNuGetProductionWebServerProductionPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryNuGetProductionWebServerProductionPackagePortConfigRootKey"]]),"Production").ToString()
'@

  #  Package Repository Source location PowershellGet
  $global:configRootKeys['RepositoryPowershellGetFilesystemDevelopmentPackageNameConfigRootKey']                         = 'ReposistoryPowershellGetFilesystemDevelopmentPackage'
  $global:configRootKeys['RepositoryPowershellGetFilesystemDevelopmentPackagePathConfigRootKey']                         = 'Join-Path $global:settings[$global:configRootKeys["RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey"]] "PowershellGet" "Development"'
  $global:configRootKeys['RepositoryPowershellGetFilesystemQualityAssurancePackageNameConfigRootKey']                    = 'RepositoryPowershellGetFilesystemQualityAssurancePackage'
  $global:configRootKeys['RepositoryPowershellGetFilesystemQualityAssurancePackagePathConfigRootKey']                    = 'Join-Path $global:settings[$global:configRootKeys["RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey"]] "PowershellGet" "QualityAssurance"'
  $global:configRootKeys['RepositoryPowershellGetFilesystemProductionPackageNameConfigRootKey']                          = 'RepositoryPowershellGetFilesystemProductionPackage'
  $global:configRootKeys['RepositoryPowershellGetFilesystemProductionPackagePathConfigRootKey']                          = 'Join-Path $global:settings[$global:configRootKeys["RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey"]] "PowershellGet" "Production"'

  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageProtocolConfigRootKey']      = 'http'
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey'] = 'http'
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerProductionPackageProtocolConfigRootKey']       = 'http'
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerDevelopmentPackageProtocolConfigRootKey']            = 'http'
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerQualityAssurancePackageProtocolConfigRootKey']       = 'http'
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerProductionPackageProtocolConfigRootKey']             = 'http'
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageServerConfigRootKey']        = 'utat022'
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey']   = 'utat022'
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerProductionPackageServerConfigRootKey']         = 'utat022'
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerDevelopmentPackageServerConfigRootKey']              = 'utat022'
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerQualityAssurancePackageServerConfigRootKey']         = 'utat022'
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerProductionPackageServerConfigRootKey']               = 'utat022'
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackagePortConfigRootKey']          = '1012'
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey']     = '1011'
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerProductionPackagePortConfigRootKey']           = '1010'
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerDevelopmentPackagePortConfigRootKey']                = '1002'
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerQualityAssurancePackagePortConfigRootKey']           = '1001'
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerProductionPackagePortConfigRootKey']                 = '1000'

  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageURIConfigRootKey']           = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackagePortConfigRootKey"]]),"Development").ToString()
'@
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey']      = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey"]]),"QualityAssurance").ToString()
'@
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerProductionPackageURIConfigRootKey']            = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryPowershellGetQualityAssuranceWebServerProductionPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetQualityAssuranceWebServerProductionPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetQualityAssuranceWebServerProductionPackagePortConfigRootKey"]]),"Production").ToString()
'@
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerDevelopmentPackageURIConfigRootKey']                 = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryPowershellGetProductionWebServerDevelopmentPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetProductionWebServerDevelopmentPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetProductionWebServerDevelopmentPackagePortConfigRootKey"]]),"Development").ToString()
'@
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerQualityAssurancePackageURIConfigRootKey']            = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryPowershellGetProductionWebServerQualityAssurancePackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetProductionWebServerQualityAssurancePackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetProductionWebServerQualityAssurancePackagePortConfigRootKey"]]),"QualityAssurance").ToString()
'@
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerProductionPackageURIConfigRootKey']                  = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryPowershellGetProductionWebServerProductionPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetProductionWebServerProductionPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryPowershellGetProductionWebServerProductionPackagePortConfigRootKey"]]),"Production").ToString()
'@

  # Package Repository Source location Chocolatey
  $global:configRootKeys['RepositoryChocolateyFilesystemDevelopmentPackageNameConfigRootKey']                            = 'ReposistoryChocolateyFilesystemDevelopmentPackage'
  $global:configRootKeys['RepositoryChocolateyFilesystemDevelopmentPackagePathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey"]] "Chocolatey" "Development"'
  $global:configRootKeys['RepositoryChocolateyFilesystemQualityAssurancePackageNameConfigRootKey']                       = 'RepositoryChocolateyFilesystemQualityAssurancePackage'
  $global:configRootKeys['RepositoryChocolateyFilesystemQualityAssurancePackagePathConfigRootKey']                       = 'Join-Path $global:settings[$global:configRootKeys["RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey"]] "Chocolatey" "QualityAssurance"'
  $global:configRootKeys['RepositoryChocolateyFilesystemProductionPackageNameConfigRootKey']                             = 'RepositoryChocolateyFilesystemProductionPackage'
  $global:configRootKeys['RepositoryChocolateyFilesystemProductionPackagePathConfigRootKey']                             = 'Join-Path $global:settings[$global:configRootKeys["RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey"]] "Chocolatey" "Production"'

  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageProtocolConfigRootKey']         = 'http'
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey']    = 'http'
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerProductionPackageProtocolConfigRootKey']          = 'http'
  $global:configRootKeys['RepositoryChocolateyProductionWebServerDevelopmentPackageProtocolConfigRootKey']               = 'http'
  $global:configRootKeys['RepositoryChocolateyProductionWebServerQualityAssurancePackageProtocolConfigRootKey']          = 'http'
  $global:configRootKeys['RepositoryChocolateyProductionWebServerProductionPackageProtocolConfigRootKey']                = 'http'
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageServerConfigRootKey']           = 'utat022'
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey']      = 'utat022'
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerProductionPackageServerConfigRootKey']            = 'utat022'
  $global:configRootKeys['RepositoryChocolateyProductionWebServerDevelopmentPackageServerConfigRootKey']                 = 'utat022'
  $global:configRootKeys['RepositoryChocolateyProductionWebServerQualityAssurancePackageServerConfigRootKey']            = 'utat022'
  $global:configRootKeys['RepositoryChocolateyProductionWebServerProductionPackageServerConfigRootKey']                  = 'utat022'
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackagePortConfigRootKey']             = '1212'
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey']        = '1211'
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerProductionPackagePortConfigRootKey']              = '1210'
  $global:configRootKeys['RepositoryChocolateyProductionWebServerDevelopmentPackagePortConfigRootKey']                   = '1202'
  $global:configRootKeys['RepositoryChocolateyProductionWebServerQualityAssurancePackagePortConfigRootKey']              = '1201'
  $global:configRootKeys['RepositoryChocolateyProductionWebServerProductionPackagePortConfigRootKey']                    = '1200'

  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageURIConfigRootKey']              = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackagePortConfigRootKey"]]),"Development").ToString()
'@
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey']         = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey"]]),"QualityAssurance").ToString()
'@
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerProductionPackageURIConfigRootKey']               = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryChocolateyQualityAssuranceWebServerProductionPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyQualityAssuranceWebServerProductionPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyQualityAssuranceWebServerProductionPackagePortConfigRootKey"]]),"Production").ToString()
'@
  $global:configRootKeys['RepositoryChocolateyProductionWebServerDevelopmentPackageURIConfigRootKey']                    = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryChocolateyProductionWebServerDevelopmentPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyProductionWebServerDevelopmentPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyProductionWebServerDevelopmentPackagePortConfigRootKey"]]),"Development").ToString()
'@
  $global:configRootKeys['RepositoryChocolateyProductionWebServerQualityAssurancePackageURIConfigRootKey']               = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryChocolateyProductionWebServerQualityAssurancePackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyProductionWebServerQualityAssurancePackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyProductionWebServerQualityAssurancePackagePortConfigRootKey"]]),"QualityAssurance").ToString()
'@
  $global:configRootKeys['RepositoryChocolateyProductionWebServerProductionPackageURIConfigRootKey']                     = @'
[UriBuilder]::new(
$($global:settings[$global:configRootKeys["RepositoryChocolateyProductionWebServerProductionPackageProtocolConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyProductionWebServerProductionPackageServerConfigRootKey"]]),
$($global:settings[$global:configRootKeys["RepositoryChocolateyProductionWebServerProductionPackagePortConfigRootKey"]]),"Production").ToString()
'@


  # Structure of the subdirectories generated during the process of building a Powershell Module for public distribution
  $global:configRootKeys['GeneratedRelativePathConfigRootKey']                                                           = '_generated'
  $global:configRootKeys['GeneratedPowershellModuleConfigRootKey']                                                       = 'Join-Path $global:settings[$global:configRootKeys["GeneratedRelativePathConfigRootKey"]] "PowershellModule"'
  $global:configRootKeys['GeneratedPowershellPackagesConfigRootKey']                                                     = 'Join-Path $global:settings[$global:configRootKeys["GeneratedRelativePathConfigRootKey"]] "PowershellPackages"'
  $global:configRootKeys['GeneratedPowershellPackagesNuGetConfigRootKey']                                                           = 'Join-Path $global:settings[$global:configRootKeys["GeneratedPowershellPackagesConfigRootKey"]] "NuGet"'
  $global:configRootKeys['GeneratedPowershellPackagesPowershellGetConfigRootKey']                                                   = 'Join-Path $global:settings[$global:configRootKeys["GeneratedPowershellPackagesConfigRootKey"]] "PowershellGet"'
  $global:configRootKeys['GeneratedPowershellPackagesChocolateyGetConfigRootKey']                                                      = 'Join-Path $global:settings[$global:configRootKeys["GeneratedPowershellPackagesConfigRootKey"]] "ChocolateyGet"'

  # Structure of the subdirectories generated during the process of testing a Powershell Module or .net .DLL for public distribution
  $global:configRootKeys['GeneratedTestResultsPathConfigRootKey']                                                        = 'Join-Path $global:settings[$global:configRootKeys["GeneratedRelativePathConfigRootKey"]] "TestResults"'
  $global:configRootKeys['GeneratedUnitTestResultsPathConfigRootKey']                                                    = 'Join-Path $global:settings[$global:configRootKeys["GeneratedTestResultsPathConfigRootKey"]] "UnitTests"'
  $global:configRootKeys['GeneratedIntegrationTestResultsPathConfigRootKey']                                             = 'Join-Path $global:settings[$global:configRootKeys["GeneratedTestResultsPathConfigRootKey"]] "IntegrationTests"'
  $global:configRootKeys['GeneratedTestCoverageResultsPathConfigRootKey']                                                = 'Join-Path $global:settings[$global:configRootKeys["GeneratedTestResultsPathConfigRootKey"]] "TestCoverage"'

  # Structure of the subdirectories generated during the process of building documentation for a Powershell Module or .net .DLL for public distribution
  $global:configRootKeys['GeneratedDocumentationDestinationPathConfigRootKey']                                           = 'Join-Path $global:settings[$global:configRootKeys["GeneratedRelativePathConfigRootKey"]] "Documentation"'
  $global:configRootKeys['GeneratedStaticSiteDocumentationDestinationPathConfigRootKey']                                 = 'Join-Path $global:settings[$global:configRootKeys["GeneratedDocumentationDestinationPathConfigRootKey"]] "StaticSite"'

  $global:configRootKeys['ENVIRONMENTConfigRootKey']                                                                     = $inProcessEnvironmentVariable
}

switch ($hostname) {
  # Machine Settings
  'utat01' {
    $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]]'
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )%gl
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
    }
  }
  'utat022' { $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'D:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'D:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'Eclipse Adoptium' 'jre-17.0.2.8-hotspot', 'bin', 'java.exe'
      $global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']                           = 'filesystem:' + (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities' 'Databases' 'ATAPUtilities' 'Flyway' 'sql')
      $global:configRootKeys['FLYWAY_URLConfigRootKey']                                 = 'jdbc:sqlserver://localhost:1433;databaseName=ATAPUtilities'
      $global:configRootKeys['FLYWAY_USERConfigRootKey']                                = 'AUADMIN'
      $global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']                            = 'NotSecret'
      $global:configRootKeys['FP__projectNameConfigRootKey']                            = 'ATAPUtilities'
      $global:configRootKeys['FP__projectDescriptionConfigRootKey']                     = 'Test Flyway and Pubs samples'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )
      # Should only be set per machine if the machine is a Jenkins Controller Node
      $global:configRootKeys['JENKINS_HOMEConfigRootKey']                               = Join-Path 'C:' 'Dropbox' 'JenkinsHome', '.jenkins'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
    }
  }
  'ncat016' { $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'D:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'D:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'D:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
    }
  }
  'ncat041' { $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/Powershell/Modules/')
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
    }
  }
  'ncat-ltb1' { $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
    }
  }
  'ncat-ltjo' { $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'D:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
    }
  }
}


# If a global variable already exists, append the local information
# This supports the ability to have multiple files define these values
# if ($global:ToBeExecutedGlobalSettings) {
#   # Load the $global:ToBeExecutedGlobalSettings with the $Local:ToBeExecutedGlobalSettings
#   $global:ToBeExecutedGlobalSettings.Keys | ForEach-Object {
#     # ToDo error hanlding if one fails
#     $global:ToBeExecutedGlobalSettings[$_] = $local:ToBeExecutedGlobalSettings[$_] # Invoke-Expression $global:SecurityAndSecretsSettings[$_]
#   }
# }
# else {
#   $global:ToBeExecutedGlobalSettings = $Local:ToBeExecutedGlobalSettings
# }


# Powershell Module Paths to be added for all users, per machine
# PSModulePathConfigRootKey

$global:JenkinsRoles = @{
  $global:configRootKeys['WindowsCodeBuildConfigRootKey']          = @(
    $global:configRootKeys['MSBuildExePathConfigRootKey']
    $global:configRootKeys['DotnetExePathConfigRootKey']
  )
  $global:configRootKeys['WindowsUnitTestConfigRootKey']           = @(
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']
  )
  $global:configRootKeys['WindowsDocumentationBuildConfigRootKey'] = @(
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']
    , $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']
    , $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey']

  )
  LinuxBuild                                                       = @{}
  MacOSBuild                                                       = @{}
  AndroidBuild                                                     = @{}
  iOSBuild                                                         = @{}
  LinuxUnitTest                                                    = @{}
  MacOSUnitTest                                                    = @{}
  AndroidUnitTest                                                  = @{}
  iOSUnitTest                                                      = @{}
  MSSQLDataBaseIntegrationTest                                     = @{
    # if the machine node has SQL server loaded, add to PSModulePath
    $global:configRootKeys['PSModulePathConfigRootKey']              = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
    $global:configRootKeys['SQLServerConnectionStringConfigRootKey'] = 'localhost:1433'
    Credentials                                                      = ''
  }
  MySQLDataBaseIntegrationTest                                     = @{}
  SQLiteDataBaseIntegrationTest                                    = @{}
  ServiceStackMSSQLDataBaseIntegrationTest                         = @{
    SERVICESTACK_LICENSE = '' # secrets guid
  }
  ServiceStackMySQLDataBaseIntegrationTest                         = @{}
  ServiceStackSQLiteDataBaseIntegrationTest                        = @{}
  DapperMSSQLDataBaseIntegrationTest                               = @{}
  DapperMySQLDataBaseIntegrationTest                               = @{}
  DapperSQLiteDataBaseIntegrationTest                              = @{}
  EFCoreMSSQLDataBaseIntegrationTest                               = @{}
  DynamicDataBaseIntegrationTest                                   = @{}
  SystemTextJsonSerializerIntegrationTest                          = @{}
  NewstonsoftSerializerIntegrationTest                             = @{}
  ServiceStackSerializerIntegrationTest                            = @{}
  DynamicSerializerIntegrationTest                                 = @{}
}

# If a global hash variable already exists, modify the global with the local information
# This supports the ability to have multiple files define these values
if ($global:MachineAndNodeSettings) {
  Write-PSFMessage -Level Debug -Message 'global:MachineAndNodeSettings are already defined '
  # Load the $global:MachineAndNodeSettings with the $Local:MachineAndNodeSettings
  $keys = $local_MachineAndNodeSettings.Keys
  foreach ($key in $keys ) {
    # ToDo error handling if one fails
    $global:MachineAndNodeSettings[$key] = $local_MachineAndNodeSettings[$key]
  }
}
else {
  Write-PSFMessage -Level Debug -Message 'global:MachineAndNodeSettings are NOT defined'
  $global:MachineAndNodeSettings = $local_MachineAndNodeSettings
}
