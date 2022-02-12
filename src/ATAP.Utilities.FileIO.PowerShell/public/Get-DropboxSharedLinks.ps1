
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
  [string]$path = 'C:\Dropbox\Photos\1Post\personal\2021-05-20-petrified-sand-dunes-loop-trail-st-george-ut' #'C:\Dropbox\Photos\1Post\personal\2021-05-17-scout-cave-trail-st-george-ut'
  , [string]$linksFile = 'links.csv'
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
  $videoSuffixHash = @{mov = @{type = 'video/mov' } ; mpg = @{type = 'vidoe/mpg' }; mp4 = @{type = 'video/mp4' } }
  $videoAtributesHash = @{mov = @{height = 'FrameHeight'; width = 'FrameWidth' } ; mpg = @{height = 'FrameHeight'; width = 'FrameWidth' }; mp4 = @{height = 'FrameHeight'; width = 'FrameWidth' } }
  $visualSortOrderPattern = '^(?<VisualSortOrder>\d+)\s*(?<Title>.+)\s*$'
  # instantiate an initial $results hash
  # ToDo: make PS Types or objects, or reference a common types file
  $results = @{
    EveryLink                 = @{}
    EveryLinkStringArray      = @()
    GalleryAllImagesAsArray   = @()
    GalleryAllImagesAsString  = ''
    Videos                    = @{}
    EveryVideoLinkStringArray = @()
    VideosAllAsString         = ''
  }
  # validate path exists
  if (!(Test-Path -Path $path)) { throw "$path was not found" }
  # Get list of files, excluding the $linksFile file
  $files = Get-ChildItem $path -Exclude $linksFile
  # get the filehash for each
  $files | ForEach-Object {
    $filehash = Get-FileHash -Path $_.FullName
    Add-Member -InputObject $_ -NotePropertyName Filehash -NotePropertyValue $filehash.Hash
    Write-Verbose "file $($_.FullName) has filehash = $($_.Filehash)"
  }
  # does the links .csv file exists
  $linksFileFullPath = Join-Path $path $linksFile
  [System.Collections.ArrayList] $currentlinksFileContent = @()
  if (Test-Path -Path $linksFileFullPath) {
    # yes, get its contents
    $currentlinksFileContent = @(Import-Csv $linksFileFullPath)
    Write-Verbose "file $linksFileFullPath has $($currentlinksFileContent.count) elements."
    # Does it have the expected contents
    if (!($currentlinksFileContent[0].Fullname)) {
      throw "$($linksFileFullPath) does not have '.fullname' member"
    }
    if (!($currentlinksFileContent[0].Extension)) {
      throw "$($linksFileFullPath) does not have '.extension' member"
    }
    if (!($currentlinksFileContent[0].Title)) {
      throw "$($linksFileFullPath) does not have '.title' member"
    }
    if (!($currentlinksFileContent[0].Filehash)) {
      throw "$($linksFileFullPath) does not have '.filehash' member"
    }
  }
  else {
    # no, create it
    Write-Verbose "Creating $linksFileFullPath"
    $files | ForEach-Object {
      $title = ''
      $visualSortOrder = 0
      $filehash = Get-FileHash -Path $_.FullName
      if ($_.basename -match $visualSortOrderPattern) {
        $title = $matches.Title
        $visualSortOrder = $matches.VisualSortOrder
      }
      else {
        # ToDo: how to handle files with no VSO number in the basename
        $title = $_.basename
        $visualSortOrder = 999
      }
      New-Object PSObject -Property @{
        'Fullname'              = $_.fullname
        'Basename'              = $_.basename
        'Extension'             = $_.Extension.TrimStart('.')
        'FileHash'              = $filehash.Hash
        'Title'                 = $title
        'VisualSortOrder'       = '{0:d3}' -f $visualSortOrder
        'DropBoxLinkToOriginal' = ''
      }
    } | Export-Csv -Path $linksFileFullPath  # ToDo add try catch for IO errors
    #    $files | %{'"' + $_.fullname + '",' + '"' + $_.basename + '",' + "{0:d3}" -f $cnt++} | Export-csv -Path $linksFileFullPath
    $currentlinksFileContent = @(Import-Csv $linksFileFullPath)
    Write-Verbose "file $linksFileFullPath has $($currentlinksFileContent.count) elements "
  }
  # compare the currentlinksFileContent to files
  $linksToBeAdded = @(Compare-Object -Ref $currentlinksFileContent.fullname -Diff $files.fullname -PassThru | Where-Object { $_.SideIndicator -eq '=>' })
  Write-Verbose "there are $($linksToBeAdded.count) files to be added."
  $linksToBeDeleted = @(Compare-Object -Ref $currentlinksFileContent.fullname -Diff $files.fullname -PassThru | Where-Object { $_.SideIndicator -eq '<=' })
  Write-Verbose "there are $($linksToBeDeleted.count) files to be deleted."
  # ToDo: Fix tthe issue, this does not return a specific link to be changed, just a hash number
  $linksToBeChanged = @(Compare-Object -Ref $currentlinksFileContent.filehash -Diff $files.filehash -PassThru | Where-Object { $_.SideIndicator -ne '==' })
  Write-Verbose "there are $($linksToBeChanged.count) files which have been changed."

  # Delete links
  if ($linksToBeDeleted.count) {
    # ToDo: This does not work, needs to be fixed
    $currentlinksFileContent = $currentlinksFileContent | Where-Object { $linksToBeDeleted -notcontains $_.fullname }
    # foreach ($o in $linksToBeDeleted) {$currentlinksFileContent.Remove($o)}
  }
  # Add links
  if ($linksToBeAdded.count) {
    $currentlinksFileContent += $linksToBeAdded | ForEach-Object { $fileinfo = Get-Item $_
      $title = ''
      $visualSortOrder = 0
      $filehash = Get-FileHash -Path $_.FullName
      if ($_.basename -match $visualSortOrderPattern) {
        $title = $matches.Title
        $visualSortOrder = $matches.VisualSortOrder
      }
      else {
        # ToDo: how to handle files with no VSO number in the basename
        $title = $_.basename
        $visualSortOrder = 999
      }

      New-Object PSObject -Property @{
        'Fullname'              = $fileinfo.fullname
        'Basename'              = $fileinfo.basename
        'Extension'             = $fileinfo.Extension.TrimStart('.')
        'FileHash'              = $filehash.Hash
        'Title'                 = $title
        'VisualSortOrder'       = '{0:d3}' -f $visualSortOrder
        'DropBoxLinkToOriginal' = ''
      }
    }
  }

  # Turn $currentlinksFileContent into a hash keyed by file path
  $currentLinksFileHash = @{}
  foreach ($row in $currentlinksFileContent) {
    $currentLinksFileHash.Add($row.fullname, $row)
  }

  # If a filehash has been changed, delete the existing DropBoxLinkToOriginal
  $linksToBeChanged | ForEach-Object{
    $currentlinksFileContent[$_.fullanme]
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
    $authorization = 'Bearer ' + $env:DropBoxAccessToken
    $headers = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
    $headers.Add('Authorization', $authorization)
    $headers.Add('Content-Type', 'application/json')
    $sharedLinkSettings = @{requested_visibility = 'public'; audience = 'public'; access = 'viewer' }
    $numMissingLinks = $missingLinks.length
    Write-Verbose "There are {$numMissingLinks} files that need sharing links"
    $linksUpdated = 0
    $missingLinks | ForEach-Object { $localpath = $_.fullname
      $result = ''
      $dropboxPath = $localpath -replace $localDropBoxPathPrefix, '' -replace '\\', '/'
      $Body = @{
        path = $dropboxPath
      }
      if ($PSCmdlet.ShouldProcess("$Path", 'Create sharing link')) {
        try {
          $result = Invoke-RestMethod -Uri $URIForListSharedLinks -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) # -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
        }
        catch {
          $resultException = $_.Exception
          $ResultExceptionMessage = $resultException.Message
          Write-Error $ResultExceptionMessage
        }
        # $result is a JSON object if there were no errors
        if ($result.links.Length) {
          #update Links File hash with DropBox link
          # Write-Verbose "localpath = {$localpath}, currentLinksFileHash[$localpath].DropBoxLinkToOriginal = {$currentLinksFileHash[$localpath].DropBoxLinkToOriginal}, $result.links[0].url = {$result.links[0].url}"
          $currentLinksFileHash[$localpath].DropBoxLinkToOriginal = $result.links[0].url -replace 'dl=0', 'raw=1'
        }
        else {
          try {
            $Body = @{
              path     = $dropboxPath
              settings = $sharedLinkSettings
            }
            $result = Invoke-RestMethod -Uri $URIForCreateSharedLinks -Method Post -Headers $headers -Body (ConvertTo-Json -InputObject $Body) # -Proxy 'http://127.0.0.1:8888' # for Fiddler capture
            # update Links File hash with DropBox link
            # Write-Verbose "localpath = {$localpath}, currentLinksFileHash[$localpath].DropBoxLinkToOriginal = {$currentLinksFileHash[$localpath].DropBoxLinkToOriginal}, $result.links[0].url = {$result.links[0].url}"
            $currentLinksFileHash[$localpath].DropBoxLinkToOriginal = $result.url -replace 'dl=0', 'raw=1'
          }
          catch {
            $resultException = $_.Exception
            $ResultExceptionMessage = $resultException.Message
            Write-Error $ResultExceptionMessage 
          }
        }
      }
      $linksUpdated++
      Write-Verbose " Finished {$linksUpdated} of {$numMissingLinks}"
    }
    # Hash table has been modified, convert to csv file
    # ToDo wrap in try/catch to handle any IO errors
    $currentLinksFileHash.values | Sort-Object -Property VisualSortOrder | Select-Object Fullname, Basename, Extension, Filehash, Title, VisualSortOrder, DropBoxLinkToOriginal | Export-Csv $linksFileFullPath
  }

  # Read the file back in
  # ToDo: use the inmemory instead of rereading the written out file - lowers attack surface. Make the writing of the file an optional parameter
  $currentlinksFileContent = @(Import-Csv $linksFileFullPath)

  # populate the $results object
  $currentlinksFileContent | Sort-Object -Property VisualSortOrder | ForEach-Object { $linksobj = $_
    $results.EveryLink[$linksobj.Fullname] = $linksobj
    $results.EveryLinkStringArray += @"
    ![$($linksobj.basename)]($($linksobj.DropBoxLinkToOriginal))
    $($linksobj.basename)
"@
  }

  # still images go into a gallery
  $results.GalleryAllImagesAsString = 'gallery:' + [System.Environment]::NewLine
  $currentlinksFileContent | Sort-Object -Property VisualSortOrder | Where-Object { !( $videoSuffixHash.Keys -contains $_.extension) } | ForEach-Object { $linksobj = $_
    $results.GalleryAllImagesAsArray += @"
    - url: $($linksobj.DropBoxLinkToOriginal)
      image_path: $($linksobj.DropBoxLinkToOriginal)
      alt: $($linksobj.basename)
      title: $($linksobj.Title)

"@
    $results.GalleryAllImagesAsString += $results.GalleryAllImagesAsArray[-1]
  }

  # video files go directly into the post body
  $currentlinksFileContent | Sort-Object -Property VisualSortOrder | Where-Object { $videoSuffixHash.Keys -contains $_.extension } | ForEach-Object { $linksobj = $_
    # get video width/height information
    $allAttrs = $linksobj.fullname | Get-FileMetaData
    # Extended file metatdata attributes are not used in the video link (yet)
    $width = $allAttrs.($videoAtributesHash[$linksobj.extension].width)
    $height = $allAttrs.($videoAtributesHash[$linksobj.extension].height)
    $results.Videos[$linksobj.fullname] += $linksobj
    # <video width=$width height=$height controls="controls">
    $results.EveryVideoLinkStringArray += @"

  <div class="container">
    <video width="100%" preload="metadata" muted controls="controls">
      <source src="$($linksobj.DropBoxLinkToOriginal)" type="$($videoSuffixHash[$linksobj.Extension].Type)" />
      Your browser does not support embedded videos, however, you can see the video in a new tab [$($linksobj.Title)]($($linksobj.DropBoxLinkToOriginal))
    </video>
    <div class="overlayText">
      <p id="topText">$($linksobj.Title)</p>
    </div>
  </div>

"@
    $results.VideosAllAsString += $results.EveryVideoLinkStringArray[-1]
  }

  Write-Output @'

  Embed this at the gallery's location
  {% include gallery id="gallery" %}
'@

  $results
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

