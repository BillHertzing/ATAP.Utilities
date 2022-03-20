function Publish-PSPackage {
  $VerbosePreference = 'Continue'
  $DebugPreference = 'Continue'
  Write-Debug ('Workspace = ' + [System.Environment]::GetEnvironmentVariable('Workspace'))
  Write-Debug ('Current Working Directory  = ' + (Get-Location))
  Write-Verbose ("Environment Variable $global:configRootKeys['ENVIRONMENTConfigRootKey'] = " + [System.Environment]::GetEnvironmentVariable($global:configRootKeys['ENVIRONMENTConfigRootKey']))

  $moduleName = [System.Environment]::GetEnvironmentVariable('ModuleName')
  Write-Verbose ('Environment Variable ModuleName = ' + $moduleName)

  $localSourceReproDirectory = [System.Environment]::GetEnvironmentVariable('LocalSourceReproDirectory')
  Write-Verbose ('Environment Variable LocalSourceReproDirectory = ' + $localSourceReproDirectory)

  $branchName = [System.Environment]::GetEnvironmentVariable('BranchName')
  Write-Verbose ('Environment Variable BranchName = ' + $branchName)

  $relativeModulePath = [System.Environment]::GetEnvironmentVariable('RelativeModulePath')
  Write-Verbose ('Environment Variable RelativeModulePath = ' + $relativeModulePath)

  $nuGetApiKey = [System.Environment]::GetEnvironmentVariable('NU_GET_API_KEY_SECRET')
  Write-Verbose ('Environment Variable RelativeModulePath = ' + $nuGetApiKey)

  $repoGitSubdirectoryPath = Join-Path $localSourceReproDirectory '.git'
  Write-Debug "repoGitSubdirectoryPath =  $repoGitSubdirectoryPath "
  $srcpath = Join-Path $localSourceReproDirectory $relativeModulePath
  Write-Debug "srcpath =  $srcpath "
  $srcPathExpansion = Join-Path $srcpath '*'
  Write-Debug "srcPathExpansion =  $srcPathExpansion "


  $directoryExclusionPattern = [regex]::Escape([IO.Path]::DirectorySeparatorChar + '(bin|obj)' + [IO.Path]::DirectorySeparatorChar) # works for all OSs
  $fileExclusionPattern = '(toc\.yml)|tags.txt|pubxml|\.md'

  $PSRepositoryName = ''
  $PSRepositorySourceLocation = ''
  $PSRepositoryPublishLocation = ''
  switch ([System.Environment]::GetEnvironmentVariable($global:configRootKeys['ENVIRONMENTConfigRootKey'])) {
    'Production' { Write-Host ' processing production values of env vars' }
    'Testing' { Write-Host ' processing production values of env vars' }
    'Development' {
      $PSRepositoryName = 'LocalDevelopmentPSRepository'
      $PSRepositorySourceLocation = '\\utat022\FS\DevelopmentPackages\PSFileRepository'
      $PSRepositoryPublishLocation = '\\utat022\FS\DevelopmentPackages\PSFileRepository'
      Write-Verbose ('PSRepositoryName = ' + $PSRepositoryName )
      Write-Verbose ('PSRepositorySourceLocation = ' + $PSRepositorySourceLocation )
      Write-Verbose ('PSRepositoryPublishLocation = ' + $PSRepositoryPublishLocation )
    }
    default { Write-Error "uh-oh, the Environemnt Variable  $global:configRootKeys['ENVIRONMENTConfigRootKey']  = " + [System.Environment]::GetEnvironmentVariable($global:configRootKeys['ENVIRONMENTConfigRootKey']) }
  }

  # First call to Get-PSRepository loads the PackageManagement.psm1. If $VerbosePreference is Continue. it prints lots of noisy lines
  $savedVerbosePreference = $VerbosePreference
  $VerbosePreference = 'SilentlyContinue'  # Comment this line out to see the package loading details
  if (-not (Get-PSRepository -Name $PSRepositoryName)) {
    Write-Debug "$PSRepositoryName is not found"
    Register-PSRepository -Name $PSRepositoryName -SourceLocation $PSRepositorySourceLocation -PublishLocation $PSRepositoryPublishLocation -InstallationPolicy Trusted
    Write-Debug "$PSRepositoryName registration completed"
  }
  $VerbosePreference = $savedVerbosePreference 

  git init #initialize the empty local repo

  # Link the remote Git repro to the workspace repro as the origin
  # unless the jenkins workspace repository already links to the remote Git repro
  $remotes = git remote -v
  if ($remotes) {
    Write-Debug 'The local git has remotes'
    $remotes | Where-Object { $_ -match '^origin' } | % { $line = $_
      Write-Debug "This remote matches '^origin' : $line"  
      if ($line -match [regex]::Escape($repoGitSubdirectoryPath)) {
        Write-Debug "This remote matches $repoGitSubdirectoryPath : $line"  
      }
      else {
        Write-Error ("This remote has an origin that does not match the job parameter. $line does not match " + [regex]::Escape($repoGitSubdirectoryPath))
      }
    }
  }
  else {
    git remote add origin -f $repoGitSubdirectoryPath     #add the remote origin
  }

  git config core.sparsecheckout true			#very crucial. this is where we tell git we are checking out specifics
  # This gets a list of files that are to be included in the PS Module
  # Get all files except those excluded by the two exclusion parameters parameters
  ((Get-ChildItem -r $srcPathExpansion |
    Where-Object { -not $_.PSIsContainer } |
    Where-Object { $_.fullname -notMatch $directoryExclusionPattern } |
    Where-Object { $_.fullname -notmatch $fileExclusionPattern } | 
    Select-Object -expand fullname) -replace $([regex]::Escape($localSourceReproDirectory)), '') -replace '\\', '/' >> .git/info/sparse-checkout #recursively checkout examples folder

  # Actually get the sparse list of files from the remote named origin for the specified branch
  git pull origin $branchName

  # Publish the module
  Publish-Module -Path $relativeModulePath -Repository $PSRepositoryName -NuGetApiKey $nuGetApiKey

  #$projFile = join-path 'src' 'ATAP.Utilities.BuildTooling.PowerShell' 'ATAP.Utilities.BuildTooling.PowerShell.pssproj'
  #write-host $projFile
  #nuget pack $projFile
}

