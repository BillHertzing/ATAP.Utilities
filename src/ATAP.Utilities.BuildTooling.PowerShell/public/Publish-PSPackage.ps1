
# Called from a Jenkins job that starts a Powershell instance using the profile of the Jenkins Service Account
#  SHould only be called on a computer that has the tools needed to perform the 'PowershellBuild' role
#  Gathers the public and private functions into a .psm1 file and updates the exported information in the .psd1 file

#region Get-ModuleHighestVersion
function Publish-PSPackage {
  # Packages called from Jenkins have no parameters, all parameters must be passed via environment variables
  #region BeginBlock
  BEGIN {
    # $DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    # $VerbosePreference = 'SilentlyContinue' # Continue SilentlyContinue
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    Write-PSFMessage -Level Debug -Message "Workspace = $([System.Environment]::GetEnvironmentVariable('Workspace'))" -Tag 'Jenkins', 'Publish'
    Write-PSFMessage -Level Debug -Message "Current Working Directory = $(Get-Location)" -Tag 'Jenkins', 'Publish'
    Write-PSFMessage -Level Debug -Message "Environment Variable Environment = $($global:configRootKeys['ENVIRONMENTConfigRootKey']) = $([System.Environment]::GetEnvironmentVariable($global:configRootKeys['ENVIRONMENTConfigRootKey']))" -Tag 'Jenkins', 'Publish'
    Write-PSFMessage -Level Debug -Message "Environment Variable ModuleName = $([System.Environment]::GetEnvironmentVariable('ModuleName'))" -Tag 'Jenkins', 'Publish'
    Write-PSFMessage -Level Debug -Message "Environment Variable LocalSourceReproDirectory = $([System.Environment]::GetEnvironmentVariable('LocalSourceReproDirectory'))" -Tag 'Jenkins', 'Publish'
    Write-PSFMessage -Level Debug -Message "Environment Variable BranchName = $([System.Environment]::GetEnvironmentVariable('BranchName'))" -Tag 'Jenkins', 'Publish'
    Write-PSFMessage -Level Debug -Message "Environment Variable RelativeModulePath = $([System.Environment]::GetEnvironmentVariable('RelativeModulePath'))" -Tag 'Jenkins', 'Publish'
    Write-PSFMessage -Level Debug -Message "Environment Variable NU_GET_API_KEY_SECRET = $([System.Environment]::GetEnvironmentVariable('NU_GET_API_KEY_SECRET'))" -Tag 'Jenkins', 'Publish'

    $moduleName = [System.Environment]::GetEnvironmentVariable('ModuleName')
    $localSourceReproDirectory = [System.Environment]::GetEnvironmentVariable('LocalSourceReproDirectory')
    $branchName = [System.Environment]::GetEnvironmentVariable('BranchName')
    $relativeModulePath = [System.Environment]::GetEnvironmentVariable('RelativeModulePath')
    $nuGetApiKey = [System.Environment]::GetEnvironmentVariable('NU_GET_API_KEY_SECRET')

    $repoGitSubdirectoryPath = Join-Path $localSourceReproDirectory '.git'
    $sourcePath = Join-Path $localSourceReproDirectory $relativeModulePath
    $sourcePathExpansion = Join-Path $sourcePath '*'
    Write-PSFMessage -Level Debug -Message "repoGitSubdirectoryPath =  $repoGitSubdirectoryPath" -Tag 'Jenkins', 'Publish'
    Write-PSFMessage -Level Debug -Message "sourcePath =  $sourcePath" -Tag 'Jenkins', 'Publish'
    Write-PSFMessage -Level Debug -Message "sourcePathExpansion =  $sourcePathExpansion" -Tag 'Jenkins', 'Publish'


    $directoryExclusionPattern = [regex]::Escape([IO.Path]::DirectorySeparatorChar + '(bin|obj)' + [IO.Path]::DirectorySeparatorChar) # works for all OSs
    $fileExclusionPattern = '(toc\.yml)|tags.txt|pubxml|\.md'

    $PSRepositoryName = ''
    $PSRepositorySourceLocation = ''
    $PSRepositoryPublishLocation = ''
    switch ([System.Environment]::GetEnvironmentVariable($global:configRootKeys['ENVIRONMENTConfigRootKey'])) {
      'Production' {
        Write-PSFMessage -Level Debug -Message 'Publish Production' -Tag 'Jenkins', 'Publish'
      }
      'Testing' {
        Write-PSFMessage -Level Debug -Message 'Publish Testing' -Tag 'Jenkins', 'Publish'
      }
      'Development' {
        $PSRepositoryName = 'LocalDevelopmentPSRepository'
        $PSRepositorySourceLocation = '\\utat022\FS\DevelopmentPackages\PSFileRepository'
        $PSRepositoryPublishLocation = '\\utat022\FS\DevelopmentPackages\PSFileRepository'
      }
      default {
        $message = "Unknown value of Environment Variable  $global:configRootKeys['ENVIRONMENTConfigRootKey']) = $([System.Environment]::GetEnvironmentVariable($global:configRootKeys['ENVIRONMENTConfigRootKey']))"
        Write-PSFMessage -Level Error -Message $message -Tag 'Jenkins', 'Publish'
        throw $Message
      }
    }
    Write-Verbose ('PSRepositoryName = ' + $PSRepositoryName )
    Write-Verbose ('PSRepositorySourceLocation = ' + $PSRepositorySourceLocation )
    Write-Verbose ('PSRepositoryPublishLocation = ' + $PSRepositoryPublishLocation )

    # First call to Get-PSRepository loads the PackageManagement.psm1 if not already loaded. If $VerbosePreference is Continue. it prints lots of noisy lines
    $savedVerbosePreference = $VerbosePreference
    $VerbosePreference = 'SilentlyContinue'  # Comment this line out to see the package loading details
    if (-not (Get-PSRepository -Name $PSRepositoryName)) {
      Write-PSFMessage -Level Debug -Message "The PSRepositoryName is not found. PSRepositoryName = $PSRepositoryName" -Tag 'Jenkins', 'Publish'
      Register-PSRepository -Name $PSRepositoryName -SourceLocation $PSRepositorySourceLocation -PublishLocation $PSRepositoryPublishLocation -InstallationPolicy Trusted
      Write-PSFMessage -Level Debug -Message "The PSRepositoryName has been registered. PSRepositoryName = $PSRepositoryName" -Tag 'Jenkins', 'Publish'
    }
    $VerbosePreference = $savedVerbosePreference

    git init # initialize the empty local repo

    # Link the remote Git repro to the workspace repro as the origin
    # unless the jenkins workspace repository already links to the remote Git repro
    $remotes = git remote -v
    if ($remotes) {
      foreach ($remote in $remotes) {
        if ($remote -match '^origin') {
          if ($remote -match [regex]::Escape($repoGitSubdirectoryPath)) {
            Write-PSFMessage -Level Debug -Message "$remote matches $repoGitSubdirectoryPath" -Tag 'Jenkins', 'Publish'
          } else {
            $message = "This remote has an origin that does not match the job parameter. $line does not match " + [regex]::Escape($repoGitSubdirectoryPath)
            Write-PSFMessage -Level Error -Message $message -Tag 'Jenkins', 'Publish'
            Throw $message
          }
        }
      }
    } else {
      Write-PSFMessage -Level Debug -Message "Adding repoGitSubdirectoryPath as remote origin. repoGitSubdirectoryPath = $repoGitSubdirectoryPath" -Tag 'Jenkins', 'Publish'
      git remote add origin -f $repoGitSubdirectoryPath
    }
    # very crucial. this is where we tell git we are checking out only SOME of the files in the repository
    git config core.sparsecheckout true
    # This gets a list of files that are to be included in the PS Module
    # Get all files except those excluded by the two exclusion parameters parameters
  ((Get-ChildItem -r $sourcePathExpansion |
        Where-Object { -not $_.PSIsContainer } |
        Where-Object { $_.fullname -notMatch $directoryExclusionPattern } |
        Where-Object { $_.fullname -notmatch $fileExclusionPattern } |
        # Get the fullname of each file, then truncate the first part up through the source repro path, then fix thepath seperators, then append the results to a file
        Select-Object -expand fullname) -replace $([Regex]::Escape($localSourceReproDirectory)), '') -replace '\\', '/' >> .git/info/sparse-checkout

    # pull the sparse list of files from the remote named origin for the specified branch
    git pull origin $branchName

    # Publish the module
    Publish-Module -Path $relativeModulePath -Repository $PSRepositoryName -NuGetApiKey $nuGetApiKey

    #$projFile = join-path 'src' 'ATAP.Utilities.BuildTooling.PowerShell' 'ATAP.Utilities.BuildTooling.PowerShell.pssproj'
    #write-host $projFile
    #nuget pack $projFile

    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion Get-ModuleHighestVersion
#############################################################################


