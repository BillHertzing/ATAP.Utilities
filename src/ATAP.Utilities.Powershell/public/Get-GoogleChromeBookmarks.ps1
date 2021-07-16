#region Get-FilesWithContent
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
# Attribution: [Testing Google Chrome Bookmarks with PowerShell](https://jdhitsolutions.com/blog/powershell-3-0/2591/friday-fun-testing-google-chrome-bookmarks-with-powershell/) Validate link r by Jeff Hickseturns 200, dated 2012-11-23
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-GoogleChromeBookmarks {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Paramter set to suport LiteralPath
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $Path
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)][switch] $Validate
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    $DebugPreference = 'Continue'

    # default values for settings
    $settings = @{
      Path     = "$env:localappdata\Google\Chrome\User Data\Default\Bookmarks"
      Validate = ''
    }

    # Things to be initialized after settings are processed
    if ($Path) { $Settings.Path = $Path }
    if ($Validate) { $Settings.Validate = $Validate }

    # In and out directory and file validations
    if (-not (Test-Path -Path $settings.Path -PathType leaf)) { throw "$settings.Path is not a file" }

    # ToDo: move to private
    #A nested function to enumerate bookmark folders
    Function Get-BookmarkFolder {
      [cmdletbinding()]
      Param(
        [Parameter(Position = 0, ValueFromPipeline = $True)]
        $Node
      )
      PROCESS {
        foreach ($child in $node.children) {
          #get parent folder name
          $parent = $node.Name
          if ($child.type -eq 'Folder') {
            Write-Verbose "Processing $($child.Name)"
            Get-BookmarkFolder $child
          }
          else {
            $hash = [ordered]@{
              Folder = $parent
              Name   = $child.name
              URL    = $child.url
              Added  = [datetime]::FromFileTime(([double]$child.Date_Added) * 10)
              Valid  = $Null
              Status = $Null
            }
            If ($Validate) {
              Write-Verbose "Validating $($child.url)"
              if ($child.url -match '^http') {
                #only test if url starts with http or https
                Try {
                  $r = Invoke-WebRequest -Uri $child.url -DisableKeepAlive -UseBasicParsing
                  if ($r.statuscode -eq 200) {
                    $hash.Valid = $True
                  } #if statuscode
                  else {
                    $hash.valid = $False
                  }
                  $hash.status = $r.statuscode
                  Remove-Variable -Name r -Force
                }
                Catch {
                  Write-Warning "Could not validate $($child.url)"
                  $hash.valid = $False
                  $hash.status = $Null
                }

              } #if url

            } #if validate
            #write custom object
            New-Object -TypeName PSobject -Property $hash
          } #else url
        } #foreach
      } #end PROCESS
    } #end function
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

    $acc = @{}

    $time = Measure-Command {
      #convert Google Chrome Bookmark file from JSON
      $data = Get-Content $file | Out-String | ConvertFrom-Json

      #these should be the top level "folders"
      $acc.bookmarkbar = Get-BookmarkFolder $data.roots.bookmark_bar
      $acc.other = Get-BookmarkFolder $data.roots.other
      $acc.synced = Get-BookmarkFolder $data.roots.synced
    }
    $OutObj = [PSCustomObject]@{
      Results    = $acc
      Time       = $time
      gciCommand = $gciCommand
    }
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
    return $OutObj

  }
}
