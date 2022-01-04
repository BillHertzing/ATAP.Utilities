#############################################################################
#region Set-TableCreateFromList
<#
.SYNOPSIS
Output SQL DDL code that creates a table, based on a template and a pipeline of names
.DESCRIPTION
The table creation template here has a single patternreplacement, which substitues a string that comes from the pipeline
.PARAMETER Name
The name of the table, must be valid for SQL server and N'[$name]
.PARAMETER Template
Optional template string used to create theoutput. The script has a default template
.INPUTS
The template along with the list of names combine to create SQL DDDL "Create Table " snippets
.OUTPUTS
The output snippets can be concatenated, and plaed in a migration script to create a bunch of basic tables
.EXAMPLE
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
WGH
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Set-TableCreateFromList {
#region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
  [Parameter(Mandatory = $True, ValueFromPipeline = $true,
  ValueFromPipelineByPropertyName = $true)]
  [string]$name

  ,[Parameter(Mandatory = $false)]
  [string]$replacementPattern
  )

#endregion FunctionParameters
#region FunctionBeginBlock
########################################
BEGIN {
  Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

  # default values for settings
  $settings=@{
    ReplacementPattern = @'
    CREATE TABLE dbo.${tableName}(
      Id int IDENTITY(1,1) NOT NULL
     ,	[Statement] nvarchar(512) NULL
      , CONSTRAINT PK_${tableName} PRIMARY KEY NONCLUSTERED (Id)
    ) ON [PRIMARY]

'@
MatchPattern = '^\s*(?<tableName>.+)\s*$'
}

  # Things to be initialized after settings are processed
  if ($replacementPattern) {$Settings.ReplacementPattern = $replacementPattern}

  $results = @{}

}
#endregion FunctionBeginBlock

#region FunctionProcessBlock
########################################
PROCESS {
    # match the entire input string, should be a tableName
    # $name -match '^\s*(?<tableName>.+)\s*$' -- for testing and debugging
    $name -replace $settings.MatchPattern , $settings.ReplacementPattern

}
#endregion FunctionProcessBlock

#region FunctionEndBlock
########################################
END {
  Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
}
#endregion FunctionEndBlock
}
#endregion Set-TableCreateFromList
#############################################################################

