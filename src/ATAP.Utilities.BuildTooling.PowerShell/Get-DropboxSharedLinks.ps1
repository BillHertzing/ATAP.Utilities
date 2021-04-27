#
# Get-DropboxSharedLinks.ps1
#
#
# .ENV PARAMETER DropBoxAccessToken
# The DropBox access token.

# Attributions:
# [PSDropbox](https://github.com/dmitrykamchatny/PSDropbox) great for examples and helpers

[CmdletBinding(SupportsShouldProcess = $true)]
param (
  [string]$path = "C:/Dropbox/Photos/1Post/personal/Eulogy for Molly the Dog"
  , [string]$linksFile = "links.csv"
  , [string]$localDropBoxPathPrefix = 'C:\\Dropbox'
)

function Get-DropboxSharedLinks {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $true)]
    [string]$path
    , [Parameter(Mandatory = $true)]
    [string]$linksFile
    , [Parameter(Mandatory = $true)]
    [string]$localDropBoxPathPrefix
  )
  Write-Verbose("path = $path")
  Write-Verbose("linksFile = $linksFile")
  Write-Verbose("localDropBoxPathPrefix = $localDropBoxPathPrefix")
  # validate path exists
  if (!(test-path -Path $path)) { throw "$path was not found" }
  # Get list of files, excluding the $linksFile file
  $files = get-childitem  $path -exclude $linksFile
  # does the links .csv file exists
  $linksFileFullPath = Join-path $path $linksFile
  $currentlinksFileContent = ""
  if (test-path -Path $linksFileFullPath) {
    # yes, get its contents
    Write-Verbose "file $linksFileFullPath contains: "
    $currentlinksFileContent = @(Import-csv $linksFileFullPath)
    Write-Verbose "file $linksFileFullPath has $($currentlinksFileContent.count) elements "
    # Does it have the expected contents
    if (!($currentlinksFileContent.fullname)) {
      throw "$($linksFileFullPath) does not have '.fullname' member"
    }
  }
  else {
    # no, create it
    Write-Verbose "Creating $linksFileFullPath"
    $files | ForEach-Object {
      New-Object PSObject -Property @{
        'Fullname'              = $_.fullname
        'Basename'              = $_.basename
        'VisualSortOrder'       = "{0:d3}" -f $cnt++
        'DropBoxLinkToOriginal' = ''
      }
    } | Export-csv -Path $linksFileFullPath  # ToDo add try catch for IO errors
    #    $files | %{'"' + $_.fullname + '",' + '"' + $_.basename + '",' + "{0:d3}" -f $cnt++} | Export-csv -Path $linksFileFullPath
    $currentlinksFileContent = @(Import-csv $linksFileFullPath)
    Write-Verbose "file $linksFileFullPath has $($currentlinksFileContent.count) elements "
  }
  # compare the currentlinksFileContent to files
  $linksToBeAdded = @(Compare-Object -Ref $currentlinksFileContent.fullname -Diff $files.fullname -passthru | ? { $_.SideIndicator -eq "=>" })
  Write-Verbose "there are $($linksToBeAdded.count) files to be added."
  $linksToBeDeleted = @(Compare-Object -Ref $currentlinksFileContent.fullname -Diff $files.fullname -passthru | ? { $_.SideIndicator -eq "<=" })
  Write-Verbose "there are $($linksToBeDeleted.count) files to be deleted."

  # Delete links
  if ($linksToBeDeleted.count) {
    $currentlinksFileContent = $currentlinksFileContent | Where-Object { $linksToBeDeleted -notcontains $_ }
  }
  # Add links
  if ($linksToBeAdded.count) {
    $currentlinksFileContent += $linksToBeAdded | ForEach-Object { $fileinfo = get-item $_
      New-Object PSObject -Property @{
        'Fullname'              = $fileinfo.fullname
        'Basename'              = $fileinfo.basename
        'VisualSortOrder'       = "{0:d3}" -f $cnt++
        'DropBoxLinkToOriginal' = ''
      }
    }
  }

  # Turn $currentlinksFileContent into a hash keyed by file path
  $currentLinksFileHash = @{}
  foreach ($row in $currentlinksFileContent) {
    $currentLinksFileHash.Add($row.fullname, $row)
  }
  # Links missing the Dropbox sharinglink
  $missingLinks = @($currentlinksFileContent | Where-Object { $_.DropBoxLinkToOriginal -eq '' })

  if ($missingLinks.count) {
    # Return dropbox sharing links, create one if needed
    $URIForCreateSharedLinks = 'https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings'
    $URIForListSharedLinks = 'https://api.dropboxapi.com/2/sharing/list_shared_links'
    # $URIForCurrentAccountInfo = 'https://api.dropboxapi.com/2/users/get_current_account' # for testing account access
    # $result = Invoke-RestMethod -Uri $URI -Method Post -Headers $headers  -Body 'null' -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
    # $URIForEcho = 'http://urlecho.appspot.com/echo?status=200&Content-Type=text%2Fhtml&body=Hello%20world!' # For connectivity and monitoring testing
    # $result = Invoke-RestMethod -Uri $URI -Method Post -Proxy 'http://127.0.0.1:8888' # For connectivity and monitoring testing
    $authorization = "Bearer " + $env:DropBoxAccessToken
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $authorization)
    $headers.Add("Content-Type", 'application/json')
    $sharedLinkSettings = @{requested_visibility = "public"; audience = "public"; access = "viewer" }
    $numMissingLinks = $missingLinks.length
    Write-Verbose "There are {$numMissingLinks} files that need sharing links"
    $linksUpdated = 0
    $missingLinks | % { $localpath = $_.fullname
      $result = ''
      $dropboxPath = $localpath -replace $localDropBoxPathPrefix, '' -replace '\\', '/'
      $Body = @{
        path = $dropboxPath
      }
      if ($PSCmdlet.ShouldProcess("$Path", "Create sharing link")) {
        try {
          $result = Invoke-RestMethod -Uri $URIForListSharedLinks -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
        }
        catch {
          $resultException = $_.Exception
          $ResultError = $resultException.Response.GetResponseStream()
          Get-DropboxError -Result $ResultError
        }
        # $result is a JSON object if there were no errors
        if ($result.links.Length) {
          #update Links File hash with DropBox link
          # Write-Verbose "localpath = {$localpath}, currentLinksFileHash[$localpath].DropBoxLinkToOriginal = {$currentLinksFileHash[$localpath].DropBoxLinkToOriginal}, $result.links[0].url = {$result.links[0].url}"
          $currentLinksFileHash[$localpath].DropBoxLinkToOriginal = $result.links[0].url -replace "dl=0", "raw=1"
        }
        else {
          try {
            $Body = @{
              path     = $dropboxPath
              settings = $sharedLinkSettings
            }
            $result = Invoke-RestMethod -Uri $URIForCreateSharedLinks -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
            #update Links File hash with DropBox link
            # Write-Verbose "localpath = {$localpath}, currentLinksFileHash[$localpath].DropBoxLinkToOriginal = {$currentLinksFileHash[$localpath].DropBoxLinkToOriginal}, $result.links[0].url = {$result.links[0].url}"
            $currentLinksFileHash[$localpath].DropBoxLinkToOriginal = $result.links[0].url -replace "dl=0", "raw=1"
          }
          catch {
            $resultException = $_.Exception
            $ResultError = $resultException.Response.GetResponseStream()
            Get-DropboxError -Result $ResultError
          }
        }
      }
      $linksUpdated++
      Write-Verbose " Finished {$linksUpdated} of {$numMissingLinks}"
    }
    # Hash table has been modified, convert to csv file
    # ToDo wrap in try/catch to handle any IO errors
    $currentLinksFileHash.values | sort-object -property VisualsortOrder | Select-Object Fullname, Basename, VisualSortOrder, DropBoxLinkToOriginal | export-csv $linksFileFullPath
  }

  # Convert it to text for the post
  $currentlinksFileContent = @(Import-csv $linksFileFullPath)
  $currentlinksFileContent | ForEach-Object { $linksobj = $_
    @"
    ![$($linksobj.basename)]($($linksobj.DropBoxLinkToOriginal))
    $($linksobj.basename)
"@
  }

  write-output 'gallery:'

  $currentlinksFileContent | ForEach-Object { $linksobj = $_
    write-output @"
  - url: $($linksobj.DropBoxLinkToOriginal)
    image_path: $($linksobj.DropBoxLinkToOriginal)
    alt: $($linksobj.basename)
    title: $($linksobj.basename)
"@
}

write-output @"
  'Embed this'
  '{% include gallery id="gallery" caption="Molly" %}'
"@

1;
}

Get-DropboxSharedLinks $path $linksFile $localDropBoxPathPrefix


# These two scripts are from https://github.com/dmitrykamchatny/PSDropbox Droopbox.psm1 file

<#
.SYNOPSIS
    Get returned Dropbox Error
.DESCRIPTION
    Currently the Invoke-RestMethod command error response doesn't show the actual response received from Dropbox.

  The catch code block includes the line "$ResultError = $_.Exception.Response.GetResponseStream()" to get the response stream then passes it to this cmdlet to read.
  .EXAMPLE
  Get-DropboxError -Result $ResultError
  #>
function Get-DropboxError {
  [cmdletbinding()]
  param(
    # Invoke-RestMethod error stream.
    $Result
  )

  begin {
    $Reader = New-Object System.IO.StreamReader($Result)
  }
  process {
    $Reader.BaseStream.Position = 0
    $Reader.DiscardBufferedData()
    $DropboxError = ($Reader.ReadToEnd())
  }
  end {
    Write-Output $DropboxError
  }
}

<#
.Synopsis
 Short description
.DESCRIPTION
 Long description
.EXAMPLE
 Example of how to use this cmdlet
.EXAMPLE
 Another example of how to use this cmdlet
#>
function Get-DropboxAccount {
  [CmdletBinding()]
  Param(
    # Dropbox API access token.
    [parameter(Mandatory, HelpMessage = "Enter access token")]
    [string]$Token
  )

  Begin {
    $URI = 'https://api.dropboxapi.com/2/users/get_current_account'
    $Header = @{"Authorization" = "Bearer $Token" }
  }
  Process {
    try {
      $Result = Invoke-RestMethod -Uri $URI -ContentType "application/json" -Method Post -Body "null" -Headers $Header
      Write-Output $Result
    }
    catch {
      $ResultError = $_.Exception.Response.GetResponseStream()
      Get-DropboxError -Result $ResultError
    }
  }
  End {}
}
# Write Dropbox tokens to file

# Get Dropbox tokens from file

# Copy file to Dropbox

# Copy list of file to DropBox

# Create and return shared link to file

# Append File fullname, caption, dropbox link, sort order to a list-of-figures file

# create list-of-figures file

# Send file to resize, get back list of sizes

# create a file copy of the sp[ecific size]

