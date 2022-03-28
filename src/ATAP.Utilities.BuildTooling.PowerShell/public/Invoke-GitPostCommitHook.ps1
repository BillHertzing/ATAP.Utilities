# This script is called when a developer makes a commit on a local git repository
# It executes in the context of the developer's terminal or IDE
# It expects to be invoked in a repository's root directory
# It calls a specific Jenkins job (ATAP.Utilities.CICDPipeline)
# That job creates artifacts from the source, tests, and databases
# That job pushes artifacts created in the CICDPipeline back to the local git repository
function Invoke-GitPostCommitHook {
  [CmdletBinding(SupportsShouldProcess=$true)]
  Param()
  # The PostRelease hook has not completed successfully yet
  $exitcode = 1
  $VerbosePreference = 'Continue' # Continue  SilentlyContinue
  $DebugPreference = 'SilentlyContinue'

  Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
  Write-Verbose ("Current Working Directory = $(Get-Location)" )
  # Write-Debug ("Environment Variables at start of $($MyInvocation.Mycommand) = " + [Environment]::NewLine + $(Write-EnvironmentVariablesIndented 0 2 ))

  $userName = [System.Environment]::GetEnvironmentVariable('USERNAME')
  Write-Verbose ('Environment Variable USERNAME = ' + $userName)

  $moduleName = [System.Environment]::GetEnvironmentVariable('MODULE_NAME')
  Write-Verbose ('Environment Variable MODULE_NAME = ' + $moduleName)

  $jenkinsURL = [Environment]::GetEnvironmentVariable($global:configRootKeys['JENKINS_URLConfigRootKey'])
  Write-Verbose ('Environment Variable JENKINS_URL = ' + $jenkinsURL)

  $jobName = [System.Environment]::GetEnvironmentVariable('JOB_NAME')
  Write-Verbose ('Environment Variable JOB_NAME = ' + $jobName)
  # temp
  $jobName = 'Push-ExamplePSModule'

  $localSourceReproDirectory = [System.Environment]::GetEnvironmentVariable('LocalSourceReproDirectory')
  Write-Verbose ('Environment Variable LocalSourceReproDirectory = ' + $localSourceReproDirectory)

  $branchName = [System.Environment]::GetEnvironmentVariable('BRANCH_NAME')
  Write-Verbose ('Environment Variable BRANCH_NAME = ' + $branchName)

  $relativeModulePath = [System.Environment]::GetEnvironmentVariable('RelativeModulePath')
  Write-Verbose ('Environment Variable RelativeModulePath = ' + $relativeModulePath)

  $useProxy = [System.Environment]::GetEnvironmentVariable('USE_PROXY')
  Write-Verbose ('Environment Variable USE_PROXY = ' + $useProxy)

  $proxyAddress = [System.Environment]::GetEnvironmentVariable('PROXY_ADDRESS')
  $proxyAddress = 'http://127.0.0.1:8888'
  Write-Verbose ('Environment Variable PROXY_ADDRESS = ' + $proxyAddress)

  # ToDo: User Powershell Secrets module instead of environment varibles (which may get logged)
  $jenkinsAuthTokenForScript = [System.Environment]::GetEnvironmentVariable('JenkinsAuthTokenForScript')
  $jenkinsAuthTokenForScript ='BuildFromScriptAuthToken'
  Write-Verbose ('Environment Variable jenkinsAuthTokenForScript = ' + $jenkinsAuthTokenForScript)

  # ToDo: User Powershell Secrets module instead of environment varibles (which may get logged)
  $jenkinsUserAPIToken = [System.Environment]::GetEnvironmentVariable('jenkinsUserAPIToken')
  $jenkinsUserAPIToken = '118c73f03d6e9eef937fcf25c757a1a3ac'
  Write-Verbose ('Environment Variable jenkinsUserAPIToken = ' + $jenkinsUserAPIToken)

  ### ToDo: add -fail-fast parameter
  ### ToDo: add -force-allow parameter to allow PostCommit to pass even if the script fails

      # ToDo: Implement Powershell Secrets module for Password or Token needed to Authorize this user
  $authorization = 'Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($userName + ':' + $jenkinsUserAPIToken))
  # The URL address of the Jenkins instance to use. All->Machine->User->Process (which may take into account development for Jenkins service/server itself)
  $uRLForJobToRun            = '{0}{1}/{2}/{3}' -f $jenkinsURL, 'job', $jobName, 'build'

  #   # default values for parameters
  # $parameters = @{
  #   # ToDo: Like ConfigurationRoot, these should be built-in, then file-based, then env variable then argument
  #   # ToDo: However, no arguments to this function, because it is usually called by a Git hook (runs in the user's context)
  #   # The URI address of the Jenkins instance to use. All->Machine->User->Process (which may take into account development for Jenkins service/server itself)
  #   #URIBuilder = [System]::UriBuilder('http', 'utat022', int port, string? path, string? extraValue);
  #   URLForjobToRun            = '{0}{1}/{2}/{3}' -f $jenkinsURL, 'job', $jobName, 'build'
  #   #URLForRequestCrumb        = '{0}{1}' -f $jenkinsURL, 'crumbIssuer/api/json'
  #   # [REST API call with Basic Authentication in Powershell](https://pallabpain.wordpress.com/2016/09/14/rest-api-call-with-basic-authentication-in-powershell/)
  #   # ToDo: Implement Powershell Secrets module for Password or Token needed to Authorize this user
  #   Authorization             = 'Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes([System.Environment]::GetEnvironmentVariable('USERNAME', 'process') + ':' + $jenkinsUserAPIToken)) #'NotSecret'))
  #   # ToDo: Implement Powershell Secrets module for Token needed to allow this Jenkins Job to be triggered by a Powershell script
  #   JenkinsAuthTokenForScript = $jenkinsAuthTokenForScript
  # }

  $headers = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
  $headers.Add('Authorization', $authorization)

  ### This commentred block is good example for using Authorization toget a crumb.
  # $headers.Add('Authorization', $parameters.authorization)
  # $headers.Add('Content-Type', 'application/json')
  # $qs_data = @{}
  # $url = "'{0}?{1}'" -f $parameters.URLForRequestCrumb , ($qs_array -join '&')
  # $command = "Invoke-RestMethod -Uri $url -Headers " + '$headers  -Method GET'
  # if ($useProxy) { $command += " -Proxy $proxyAddress" }
  # Write-Debug "command = $command"
  # if ($PSCmdlet.ShouldProcess($parameters.URLForRequestCrumb, 'HTTP call to the Jenkins URL to get a crumb for this user')) {
  # try {
  #   $result = invoke-Expression $command
  #   Write-Debug "result = $result"
  #   $headers.Add($result.crumbRequestField, $result.crumb)
  #   #$headers.Remove('Authorization')
  #   #$headers.Add($result.crumbRequestField, 'd53e33b3e69038f175ce3ae81c7c3d63f3aa674956c95a1040a5a88e4d89e6a7')
  # }
  # catch {
  #   $resultException = $_.Exception
  #   $ResultExceptionMessage = $resultException.Message
  #   Write-Error $ResultExceptionMessage
  #   # ToDo: figure out how to abort a GitHook powershell script elegantly
  #   throw $ResultExceptionMessage
  # }

  # define the QueryString parameters and values
  $qs_data = @{
    'token' = $jenkinsAuthTokenForScript
    'delay' = '0sec'
  }

  # UrlEncode the QueryString parameters
  [System.Collections.ArrayList] $qs_array = @()
  foreach ($qs in $qs_data.GetEnumerator()) {
    $qs_key = [System.Web.HttpUtility]::UrlEncode($qs.Name)
    $qs_value = [System.Web.HttpUtility]::UrlEncode($qs.Value)
    $qs_array.Add("${qs_key}=${qs_value}") | Out-Null
  }

  # combine the `URLForjobToRun` with the encoded QueryString parameters
  $url = "'{0}?{1}'" -f $uRLForJobToRun , ($qs_array -join '&')
  $command = "Invoke-RestMethod -Uri $url -Headers " + '$headers  -Method POST'
  if ($useProxy -and -not (($useProxy -eq 0) -or ($useProxy -eq $false))) { $command += " -Proxy $proxyAddress" }
 if ($PSCmdlet.ShouldProcess($command, "Would run $command ")) {
  try {
    $result = Invoke-Expression $command
    Write-Debug "result = $result"
  }
  catch {
    $resultException = $_.Exception
    $ResultExceptionMessage = $resultException.Message
    Write-Error $ResultExceptionMessage
  }
}

  # $result is a JSON object if there were no errors


  $exitcode
}


