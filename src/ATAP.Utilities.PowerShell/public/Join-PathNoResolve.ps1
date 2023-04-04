#############################################################################
#region Join-PathNoResolve
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Path
  Specifies the path where searching should start. May be a string or an array in the form (p1[,p2][,p3]...)
.PARAMETER FileNamePattern
  Specifies the regex pattern to match filenames against. May be a string or an array in the form (r1[,r2][,r3]...)

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
Function Join-PathNoResolve {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Paramter set to suport LiteralPath
    # [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $Path
    [ValidateNotNullorEmpty()][string] $Path
    , [ValidateNotNullorEmpty()][string] $ChildPath
    , [string[]] $AdditionalPaths
    , [char] $DirectorySeparatorChar = [IO.Path]::DirectorySeparatorChar
  )
  $result = ''
  $numCharacters = $(Measure-Object -InputObject $Path -Character).Characters
  if ($numCharacters -eq 1) {
    # if Path has just 1 character, use Join-Path
    $result = Join-Path $Path $ChildPath $AdditionalPaths
  }
  elseif ($Path.Substring(1, 1) -ne ':') {
    # if Path doesn't start with a Drive letter, then use Join-Path
    $result = Join-Path $Path $ChildPath $AdditionalPaths
  }
  else {
    # Path starts with a drive letter (because it has ':' as second character) so we can't use join-path for the $Path portion, have to emulate it's behaviour
    # The $DirectorySeparatorChar to use depends on the parameter
    if ($Path.Substring($numCharacters - 1, 1) -eq $DirectorySeparatorChar) {
      # However, we can use join-path for the second and remainder arguments
      $result = "$($Path)$($DirectorySeparatorChar)$(Join-Path $ChildPath $AdditionalPaths)"
      # ToDo: replace $DirectorySeparatorChar used by Join-Path if there is a parameter $DirectorySeparatorChar and it differes from the current OS's DirectorySeparatorChar
    }
    else {
      # second character in $Path is not ':' so we can use join-path
      $result = "$($Path)$(Join-Path $ChildPath $AdditionalPaths)"
    }
  }
  $result
}
#endregion Join-PathNoResolve
#############################################################################


