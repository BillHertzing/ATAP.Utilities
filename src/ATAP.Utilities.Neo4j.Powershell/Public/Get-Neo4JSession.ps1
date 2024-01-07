
#############################################################################
#region Get-Neo4JSession
<#
.SYNOPSIS
Gets a connected Neo4j Session object.
.DESCRIPTION
Gets a connected Neo4j Session object. Uses default values, configuration file(s), environment variables, and command-line arguments
.PARAMETER URI
the URI for the neo4j database's endpoint. defaults to the BOLT protocol and the default neo4j port for BOLT
.PARAMETER UserName
UserName for the connection. Defaultsto 'neo4j'
.PARAMETER Password
UserName for the connection. Defaultsto 'NotSecreat'
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
Function Get-Neo4JSession {
  #region FunctionParameters
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
    [parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $InDir = '..\Data'
    ,[alias('InBusinessName1FilePattern')]
    [parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $InFn1
    ,[alias('InBusinessName2FilePattern')]
    [parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $InFn2
    ,[parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $OutDir
    ,[alias('OutFNBusinessName1')]
    [parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $OutFn1
    ,[alias('OutFNBusinessName2')]
    [parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] $OutFn2
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
     $DebugPreference = 'Continue'

    # default values for settings
    $settings=@{
      InDir = '..\Data'
      InBusinessName1FilePattern = 'statistics'
      InBusinessName2FilePattern = 'unused'
      OutDir = '.'
      OutFNBusinessName1 = 'OutName1-'+(Get-Date).ToString('yyyyMMdd')+'.cfg'
      OutFNBusinessName2 = 'OutName2-'+(Get-Date).ToString('yyyyMMdd')+'.cfg'
    }

    # Things to be initialized after settings are processed
    if ($InDir) {$Settings.InDir = $InDir}
    if ($InFn1) {$Settings.InBusinessName1FilePattern = $InFn1}
    if ($InFn2) {$Settings.InBusinessName2FilePattern = $InFn2}
    if ($OutDir) {$Settings.OutDir = $OutDir}
    if ($OutFn1) {$Settings.OutFNBusinessName1 = $OutFn1}
    if ($OutFn2) {$Settings.OutFNBusinessName2 = $OutFn2}
    if ($OutFn3) {$Settings.OutFnOnDemandRules = $OutFn3}

    Add-Type -Path "$PSScriptRoot\Neo4j.Driver.1.0.2\lib\dotnet\Neo4j.Driver.dll"
    Add-Type -Path "$PSScriptRoot\rda.SocketsForPCL.1.2.2\lib\net45\Sockets.Plugin.Abstractions.dll"
    Add-Type -Path "$PSScriptRoot\rda.SocketsForPCL.1.2.2\lib\net45\Sockets.Plugin.dll"  $results = @{}
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
  #
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
  }
  #endregion Get-Neo4JSession
  #############################################################################


