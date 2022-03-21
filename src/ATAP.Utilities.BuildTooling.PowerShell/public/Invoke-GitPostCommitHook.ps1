# This script is called when a developer makes a commit on a local git repository
# It executes in the context of the developer's terminal or IDE
# It expects to be invoked in a repository's root directory
# It calls a specific Jenkins job (ATAP.Utilities.CICDPipeline)
# That job creates artifacts from the source, tests, and databases
# That job pushes artifacts created in the CICDPipeline back to the local git repository
function Invoke-GitPostCommitHook {
  # The PostRelease hook has not completed successfully yet
  $exitcode = 1
  $VerbosePreference = 'Continue' # Continue  SilentlyContinue
  $DebugPreference = 'Continue'

  Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
  Write-Debug ("Current Working Directory = $(Get-Location)" )
  # Write-Debug ("Environment Variables at start of $($MyInvocation.Mycommand) = " + [Environment]::NewLine + $(Write-EnvironmentVariablesIndented 0 2 ))

  $moduleName = [System.Environment]::GetEnvironmentVariable('ModuleName')
  Write-Verbose ('Environment Variable ModuleName = ' + $moduleName)

  $jenkinsURL = [Environment]::GetEnvironmentVariable($global:configRootKeys['JENKINS_URLConfigRootKey'])
  Write-Verbose ('Environment Variable JENKINS_URL = ' + $jenkinsURL)

  $jobName = [System.Environment]::GetEnvironmentVariable('JobName')
  Write-Verbose ('Environment Variable JobName = ' + $jobName)
  # temp
  $jobName = 'Push-ExamplePSModule'


  $localSourceReproDirectory = [System.Environment]::GetEnvironmentVariable('LocalSourceReproDirectory')
  Write-Verbose ('Environment Variable LocalSourceReproDirectory = ' + $localSourceReproDirectory)

  $branchName = [System.Environment]::GetEnvironmentVariable('BranchName')
  Write-Verbose ('Environment Variable BranchName = ' + $branchName)

  $relativeModulePath = [System.Environment]::GetEnvironmentVariable('RelativeModulePath')
  Write-Verbose ('Environment Variable RelativeModulePath = ' + $relativeModulePath)

  $relativeModulePath = [System.Environment]::GetEnvironmentVariable('RelativeModulePath')
  Write-Verbose ('Environment Variable RelativeModulePath = ' + $relativeModulePath)

  $useProxy = [System.Environment]::GetEnvironmentVariable('UseProxy')
  Write-Verbose ('Environment Variable UseProxy = ' + $useProxy)

  $proxyAddress = [System.Environment]::GetEnvironmentVariable('ProxyAddress')
  Write-Verbose ('Environment Variable ProxyAddress = ' + $proxyAddress)

  ### ToDo: add -fail-fast parameter
  ### ToDo: add -force-allow parameter to allow PostCommit to pass even if the script fails

  # Call the jenkins URL to run the JenkinsFile

  # default values for parameters
  $parameters = @{
    # ToDo: Like ConfigurationRoot, these should be built-in, then file-based, then env variable then argument
    # ToDo: However, no arguments to this function, because it is usually called by a Git hook (runs in the user's context)
    # The URI address of the Jenkins instance to use. All->Machine->User->Process (which may take into account development for Jenkins service/server itself)
    #URIBuilder = [System]::UriBuilder('http', 'utat022', int port, string? path, string? extraValue);
    URIForjobToRun    = '{0}{1}/{2}/{3}{4}' -f $jenkinsURL, 'job', $jobName, 'build', '?token=NotSecret'
    URIForRequestCrumb    = '{0}{1}/{2}/{3}{4}' -f $jenkinsURL, 'crumbIssuer/api/json'
  }


  $headers = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
  $headers.Add('Authorization', $authorization)
  #$headers.Add('Jenkins-Crumb', $authorization)
  $headers.Add('Content-Type', 'application/json')
  # if ($PSCmdlet.ShouldProcess($parameters.URIForjobToRun, 'HTTP call to the Jenkins URL to run job')) {
  try {
    # Get a crumb for the later API calls
    # $command = "Invoke-RestMethod -Uri $parameters.URIForjobToRun -Method Post" # -Headers $headers -Body (ConvertTo-Json -InputObject $Body) $paramters.ProxyString"
    # ToDo: add parameters for Proxy
    $result = Invoke-RestMethod -Uri $parameters.URIForRequestCrumb -Method Post  -Proxy 'http://127.0.0.1:8888' # Invoke-RestMethod -Uri $parameters.URIForListSharedLinks -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) -Proxy 'http://127.0.0.1:8888' # for Fiddler capture

    #$result = Invoke-Command $command
  }
  catch {
    $resultException = $_.Exception
    $ResultExceptionMessage = $resultException.Message
    Write-Error $ResultExceptionMessage
  }

  $headers.Add('Jenkins-Crumb', $jenkinsCrumb)

  # $result is a JSON object if there were no errors
  # $result.links is non-zero if a shared link already exists
  if ($result.links.Length) {
    $sharingLink = $result.links[0].url -replace 'dl=0', 'raw=1'
    Write-Verbose "path = {$dropboxPath}, sharingLink = {$sharingLink}"
  }
  else {
    # A shared link does not yet exist, so ask Dropbox to create and return one
    try {
      $Body = @{
        path     = $dropboxPath
        settings = $parameters.SharedLinkSettings
      }
      # ToDo: add parameters for Proxy

      $result = Invoke-RestMethod -Uri $parameters.URIForCreateSharedLinks -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
      $sharingLink = $result.url -replace 'dl=0', 'raw=1'
      Write-Verbose "path = {$dropboxPath}, sharingLink = {$sharingLink}"
    }
    catch {
      $resultException = $_.Exception
      $ResultExceptionMessage = $resultException.Message
      # $dmsg = $_.Exception.InnerException.Message
      Write-Error $ResultExceptionMessage
    }
  }
  # }


  $exitcode
}


