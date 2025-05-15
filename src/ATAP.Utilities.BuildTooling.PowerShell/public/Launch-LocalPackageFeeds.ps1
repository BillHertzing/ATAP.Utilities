# Launch-LocalPackageFeeds.ps1

param(
  # Configuration for BaGet feeds for multiple package types and lifecycles
  # use the information in $global:settings['PackageRepositoriesCollection'].
  # These are the providers for which the script will create a package
  # ToDO: Validation is done as follows:
  # [ValidateScript( { [ProviderNamesEnum]::IsDefined([ProviderNamesEnum], $_) } )]
  [ValidateSet('NuGet', 'PowershellGet', 'ChocolateyGet', 'ChocolateyCLI')]
  # ToDO: default to an array of enumeration values ($global:settings)
  [string[]]$providerNames = @('NuGet', 'PowershellGet', 'ChocolateyGet', 'ChocolateyCLI')
  # These are the lifecycle stages for which the script will create a package
  # ToDo: replace with an enumeration type
  , [ValidateSet('QualityAssurance', 'Production')]
  # ToDO: default to an array of enumeration values ($global:settings)
  [string[]]$packageLifecycles = @('QualityAssurance', 'Production')
)

$feeds = [System.Collections.ArrayList]::new()
$REPattern = '(?<ProviderName>NuGet|PowershellGet|ChocolateyGet)(?<ProviderLifecycle>Filesystem|QualityAssuranceWebServer|ProductionWebServer)(?<PackageLifecycle>QualityAssurance|Production)'
# ToDo: make this a hash table lookup, create additional local server computers to act as hosts for the other two provider lifecycles
# ToDo, implement additional computers to host other providerLifecycles, put them in settings
$providerLifecycleHosts = @{'Production' = 'utat022' }
$repositories = $global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']]
$repositoryKeys = $repositories.Keys
for ($repositoriesIndex = 0; $repositoriesIndex -lt $repositoryKeys.Count; $repositoriesIndex++) {
  $repository = $repositories[$($repositoryKeys)[$repositoriesIndex]]
  if ($repository -imatch $REPattern) {
    $providerName = $matches['ProviderName']
    $providerLifecycle = $matches['ProviderLifecycle']
    $providerLifecycleHost = $providerLifecycleHosts['Production']
    $packageLifecycle = $matches['PackageLifecycle']
    $feeds.Add([PSCustomObject]@{
        Name   = $providerName + $packageLifecycle
        Host   = $providerLifecycleHost # ToDo, implement additional computers to host other providerLifecycles
        Port   = $repository.Port
        Path   = $repository.Path
        Db     = 'baGet.' + $providerName + '.' + $packageLifecycle + '.db'
        ApiKey = 'UseVault' # based on providerName, providerLifecycle, packageLifecycle, and Host
      })
  } else {
    $message = "repositoriesIndex = $repositoriesIndex; repository = $repository; it does not imatch $REPattern"
    Write-PSFMessage -Level Error -Message $message -Tag 'Launch-LocalPackageFeeds'
    Throw $message
  }
}

# Path to BaGet template app
$baGetServerTemplatePath = 'C:/Dropbox/BaGetServers/BaGetTemplate'

foreach ($feed in $feeds) {
  $instanceDir = "C:/Dropbox/BaGetServers/$($feed.Name)"
  $appSettingsPath = Join-Path $instanceDir 'appsettings.json'

  if (-not (Test-Path $instanceDir)) {
    Copy-Item -Recurse -Force $baGetServerTemplatePath $instanceDir
  }

  $appSettings = @{
    Storage  = @{ Type = 'FileSystem'; Path = $feed.Path }
    Database = @{ Type = 'Sqlite'; ConnectionString = "Data Source=$($feed.Db)" }
    ApiKey   = $feed.ApiKey
  } | ConvertTo-Json -Depth 3

  $appSettings | Out-File -FilePath $appSettingsPath -Encoding utf8 -Force

  # Listen on both localhost and the host machine name
  $hostName = $env:COMPUTERNAME
  $urls = "http://localhost:$($feed.Port),http://$($hostName):$($feed.Port)"

  Write-Host "Starting BaGet [$($feed.Name)] on port $($feed.Port)..."

  Start-Process 'dotnet' -ArgumentList "BaGet.dll --urls $urls" -WorkingDirectory $instanceDir -WindowStyle Minimized
}

Write-Host 'All BaGet feed instances launched.'
