#region Get-BrowserBookmarks
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
Function Get-BrowserBookmarks {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet')]
  param (
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateSet('*', 'Chrome', 'Brave')]
    [string] $Browser
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateSet('*', 'synced', 'other', 'bookmarkbar')]
    [string] $Source
    ,[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNullOrEmpty()]
    [Alias('CN')]
    [string[]] $ComputerName
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [switch] $Validate
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    #$DebugPreference = 'Continue'
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

    # ToDo: move to private
    # A nested function to enumerate bookmark folders
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
              Title   = $child.name
              URL    = $child.url
              Added  = [datetime]::FromFileTime(([double]$child.Date_Added) * 10)
              Valid  = $Null
              Status = $Null
            }
            If ($Validate) {
              Write-Verbose "Validating $($child.url)"
              if ($child.url -match '^http') {
                # only test if url starts with http or https
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
            [PSCustomObject] $hash
          } #else url
        } #foreach
      } #end PROCESS
    } #end function
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {
    $Paths = @()
    switch ($browser) {
      'Chrome' {
        $Paths += Join-Path $env:localappdata 'Google' 'Chrome', 'User Data', 'Default', 'Bookmarks'
      }
      'Brave' { $Paths += Join-Path $env:localappdata 'BraveSoftware' 'Brave-Browser', 'User Data', 'Default', 'Bookmarks' }
      '*' {
        $Paths += Join-Path $env:localappdata 'Google' 'Chrome', 'User Data', 'Default', 'Bookmarks'
        $Paths += Join-Path $env:localappdata 'BraveSoftware' 'Brave-Browser', 'User Data', 'Default', 'Bookmarks'
      }
    }
    $acc = @()

    foreach ($path in $Paths) {
      if (-not (Test-Path -Path $path -PathType leaf)) {
        throw "$path is not a file"
      }
      # convert Google Chrome Bookmark file from JSON
      #ToDo: $Encoding
        $data = Get-Content $path | Out-String | ConvertFrom-Json
        switch ($Source) {
          'bookmarkbar' {
            $acc = Get-BookmarkFolder $data.roots.bookmark_bar
          }
          'synced' {
            $acc = Get-BookmarkFolder $data.roots.other
          }
          'other' {
            $acc = Get-BookmarkFolder $data.roots.synced
          }
          '*' {
            $acc = Get-BookmarkFolder $data.roots.bookmark_bar
            $acc += Get-BookmarkFolder $data.roots.other
            $acc += Get-BookmarkFolder $data.roots.synced
          }
        }
      }
      $acc
  }
  #endregion ProcessBlock
  #region EndBlock
  END {
        Write-PSFMessage -Level Debug -Message 'Ending Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}


