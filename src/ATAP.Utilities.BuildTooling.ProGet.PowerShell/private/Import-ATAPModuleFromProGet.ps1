function Import-ATAPModuleFromProGet {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ModuleName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$RequiredCommand,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$RepositoryName = 'powershellget-stable',

    [Parameter(Mandatory = $false)]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser'
  )

  $fn = 'Import-ATAPModuleFromProGet'
  $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'

  if (Get-Command -Name $RequiredCommand -CommandType Function, Cmdlet -ErrorAction SilentlyContinue) {
    return
  }

  $sourceLocation = $null
  if (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue) {
    try {
      $feed = Resolve-ProGetFeedFromSettings -FeedType 'powershell' -Tier 'Production'
      if ($null -ne $feed) {
        if (-not [string]::IsNullOrWhiteSpace([string]$feed.FeedName)) {
          $RepositoryName = [string]$feed.FeedName
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$feed.Uri)) {
          $sourceLocation = [string]$feed.Uri
        } elseif (-not [string]::IsNullOrWhiteSpace([string]$feed.EndpointUri)) {
          $sourceLocation = [string]$feed.EndpointUri
        }
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Resolve-ProGetFeedFromSettings did not provide feed metadata. Falling back to direct ProGet defaults. Exception: $($_.Exception.Message)"
    }
  }

  if ([string]::IsNullOrWhiteSpace($sourceLocation)) {
    $scheme = [string]$env:ProGetScheme
    $hostName = [string]$env:ProGetHost
    $portValue = [string]$env:ProGetPort

    if ($null -ne $global:Settings) {
      if ([string]::IsNullOrWhiteSpace($scheme) -and (Get-Command -Name 'Resolve-BuildToolingSettingValue' -CommandType Function -ErrorAction SilentlyContinue)) {
        try { $scheme = [string](Resolve-BuildToolingSettingValue -Name 'ProGetAdminUriScheme') } catch {}
      }
      if ([string]::IsNullOrWhiteSpace($hostName) -and (Get-Command -Name 'Resolve-BuildToolingSettingValue' -CommandType Function -ErrorAction SilentlyContinue)) {
        try { $hostName = [string](Resolve-BuildToolingSettingValue -Name 'ProGetAdminUriHost') } catch {}
      }
      if ([string]::IsNullOrWhiteSpace($portValue) -and (Get-Command -Name 'Resolve-BuildToolingSettingValue' -CommandType Function -ErrorAction SilentlyContinue)) {
        try { $portValue = [string](Resolve-BuildToolingSettingValue -Name 'ProGetAdminUriPort') } catch {}
      }
    }

    if ([string]::IsNullOrWhiteSpace($scheme)) { $scheme = 'http' }
    if ([string]::IsNullOrWhiteSpace($hostName)) { $hostName = 'localhost' }
    $port = 50000
    if (-not [string]::IsNullOrWhiteSpace($portValue)) {
      $parsedPort = 0
      if ([int]::TryParse($portValue, [ref]$parsedPort) -and $parsedPort -gt 0) {
        $port = $parsedPort
      }
    }

    $sourceLocation = ([UriBuilder]::new($scheme, $hostName, $port, "nuget/$RepositoryName/", '')).Uri.ToString()
  }

  $repository = Get-PSRepository -Name $RepositoryName -ErrorAction SilentlyContinue
  if ($null -eq $repository) {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Registering PSRepository '$RepositoryName' at '$sourceLocation'"
    Register-PSRepository -Name $RepositoryName -SourceLocation $sourceLocation -PublishLocation $sourceLocation `
      -InstallationPolicy Trusted -ErrorAction Stop
  } elseif ($repository.InstallationPolicy -ne 'Trusted') {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Marking PSRepository '$RepositoryName' as Trusted"
    Set-PSRepository -Name $RepositoryName -InstallationPolicy Trusted -ErrorAction Stop
  }

  $installedModule = Get-Module -Name $ModuleName -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1

  $remoteModule = $null
  try {
    $remoteModule = Find-Module -Name $ModuleName -Repository $RepositoryName -ErrorAction Stop
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Latest stable '$ModuleName' on '$RepositoryName' is version $($remoteModule.Version)"
  }
  catch {
    if ($null -eq $installedModule) {
      throw "Module '$ModuleName' is not installed and could not be resolved from ProGet repository '$RepositoryName'. Exception: $($_.Exception.Message)"
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
      -Message "Unable to query '$RepositoryName' for '$ModuleName'. Falling back to installed version $($installedModule.Version). Exception: $($_.Exception.Message)"
  }

  $needsInstall = ($null -eq $installedModule)
  if (($null -ne $remoteModule) -and ($null -ne $installedModule) -and ($installedModule.Version -lt $remoteModule.Version)) {
    $needsInstall = $true
  }

  if ($needsInstall -and ($null -ne $remoteModule)) {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Installing '$ModuleName' version $($remoteModule.Version) from '$RepositoryName' to scope '$Scope'"
    try {
      Install-Module -Name $ModuleName -Repository $RepositoryName -Scope $Scope -Force -AllowClobber -ErrorAction Stop
      $installedModule = Get-Module -Name $ModuleName -ListAvailable |
        Sort-Object Version -Descending |
        Select-Object -First 1
    }
    catch {
      if ($null -eq $installedModule) {
        throw "Installing '$ModuleName' from '$RepositoryName' failed and no local copy is available. Exception: $($_.Exception.Message)"
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
        -Message "Install-Module failed for '$ModuleName'. Continuing with installed version $($installedModule.Version). Exception: $($_.Exception.Message)"
    }
  }

  if ($null -eq $installedModule) {
    throw "Module '$ModuleName' could not be installed or resolved locally."
  }

  Import-Module -Name $ModuleName -MinimumVersion $installedModule.Version -Force -ErrorAction Stop

  if (-not (Get-Command -Name $RequiredCommand -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
    throw "Module '$ModuleName' imported successfully, but required command '$RequiredCommand' was not exported."
  }
}
