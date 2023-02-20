

# $global:SupportedJenkinsRolesList = @($global:configRootKeys['WindowsDocumentationBuildConfigRootKey'], $global:configRootKeys['WindowsCodeBuildConfigRootKey'], $global:configRootKeys['WindowsUnitTestConfigRootKey'], $global:configRootKeys['WindowsIntegrationTestConfigRootKey'])

$PathToProjectOrSolutionFilePattern = '(.*)\.(sln|csproj)'
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


# Settings common to all machines
$local:MachineAndNodeSettings = @{

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
  $global:configRootKeys['GeneratedPowershellModuleConfigRootKey']                                                       = Join-Path '_generated' 'PowershellModule'
  $global:configRootKeys['GeneratedPowershellPackagesConfigRootKey']                                                     = Join-Path '_generated' 'PowershellPackages'
  $global:configRootKeys['GeneratedPowershellPackagesNuGetConfigRootKey']                                                = Join-Path '_generated' 'PowershellPackages' 'NuGet'
  $global:configRootKeys['GeneratedPowershellPackagesPowershellGetConfigRootKey']                                        = Join-Path '_generated' 'PowershellPackages' 'PowershellGet'
  $global:configRootKeys['GeneratedPowershellPackagesChocolateyGetConfigRootKey']                                        = Join-Path '_generated' 'PowershellPackages' 'ChocolateyGet'

  # Structure of the subdirectories generated during the process of testing a Powershell Module or .net .DLL for public distribution
  $global:configRootKeys['GeneratedTestResultsPathConfigRootKey']                                                        = Join-Path '_generated' 'TestResults'
  $global:configRootKeys['GeneratedUnitTestResultsPathConfigRootKey']                                                    = Join-Path '_generated' 'TestResults' 'UnitTests'
  $global:configRootKeys['GeneratedIntegrationTestResultsPathConfigRootKey']                                             = Join-Path '_generated' 'TestResults' 'IntegrationTests'
  $global:configRootKeys['GeneratedTestCoverageResultsPathConfigRootKey']                                                = Join-Path '_generated' 'TestResults' 'TestCoverage'

  # Structure of the subdirectories generated during the process of building documentation for a Powershell Module or .net .DLL for public distribution
  $global:configRootKeys['GeneratedDocumentationDestinationPathConfigRootKey']                                           = Join-Path '_generated' 'Documentation'
  $global:configRootKeys['GeneratedStaticSiteDocumentationDestinationPathConfigRootKey']                                 = Join-Path '_generated' 'Documentation' 'StaticSite'

  $global:configRootKeys['ENVIRONMENTConfigRootKey']                                                                     = $inProcessEnvironmentVariable
  # ToDo: support arrays in the creation of the global:settings
  # ToDo: $global:configRootKeys['AnsibleHostNamesConfigRootKey']                                                                = ('ncat041', 'ncat-ltb1', 'ncat-ltjo', 'ncat044', 'utat01', 'utat022')
}



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
