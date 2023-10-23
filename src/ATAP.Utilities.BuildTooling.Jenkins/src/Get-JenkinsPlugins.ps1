#############################################################################
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-JenkinsPlugins {
  param (
  )
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    # Location of Jenkins-cli.jar
    # ToDo: figure out why ClassPath is not working
    $jenkinsCliJarFile =  Join-Path  ([Environment]::GetEnvironmentVariable($global:configRootKeys['CommonJarsBasePathConfigRootKey'])) 'jenkins-cli.jar'
    # ToDo: rework default/environment/commandline values for $path
    $defaultInstalledPath = "/usr/share/dotnet" # Linux and MacOS
    $defaultInstalledPath = "IDontKnow" # Windows 32 on a 64-bit OS See DotNet_Root(x86)
    $defaultInstalledPath = "C:\Program Files\dotnet" # Windows 64
    $InstalledPath = "$env:DOTNET_ROOT" ? "$env:DOTNET_ROOT" : $defaultInstalledPath
    Write-Verbose "InstalledPath = $InstalledPath"
    # validate InstalledPath exists
    if (!(Test-Path -Path $InstalledPath)) { throw "$InstalledPath was not found, verify at least one DotNet Runtime or SDK has been installed" }
  }

  ########################################
  PROCESS {
    #
  }

  ########################################
  END {
      try {
        # invoke the jenkins-cli jar command and pass it the groovy script that will list the plugins and their versions
        # ToDo: allow script to override JENKINS_URL, JENKINS_USER_ID, JENKINS_API_TOKEN
        java -jar $jenkinsCliJarFile groovy = "< Get-JenkinsPlugins.groovy>"
        # Start-Process -FilePath $global:settings[$global:configRootKeys['JavaExePathConfigRootKey']] -ArgumentList "-jar $jenkinsCliJarFile groovy = Get-JenkinsPlugins.groovy' -PassThru
      } catch {
        $errorMessage = $_.Exception.Message
        Write-Host "Something went wrong`r`nError: $errorMessage"
        return ''
      }

    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
}
#############################################################################
