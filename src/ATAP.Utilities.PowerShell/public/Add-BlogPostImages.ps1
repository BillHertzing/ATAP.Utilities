

#############################################################################
#region Add-BlogPostImages
<#
.SYNOPSIS
Orchestrates the steps needed to create image files in a cloud hosting provider for blog posts
.DESCRIPTION
Creates a persistence file listing all the images in a post. Adds title and description for each image, and lists the media query versions for each file
.PARAMETER destinationDirectory
This is the path, absolute or relative, that leads to the directory where the final images should be stored
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
Function Add-BlogPostImages {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'FromDestinationDirectory')]
  # One Parameter set is for $LinksFile as the "SourceOfTruth"# # ParameterSetName = 'FromLinksFile'
  # One Parameter set is for $destinationDirectory as the "SourceOfTruth" # ParameterSetName = 'FromDestinationDirectory'
  # One Parameter set is for $SourceFiles as the "SourceOfTruth" # ParameterSetName = 'FromSourceFiles'
  # One Parameter set is to add $SourceFiles to both the existing $destinationDirectory and $linkFile
  # One Parameter set is to add $SourceImages to both the existing $destinationDirectory and $linkFile
  param (
    [alias('OutDir')]
    [parameter(ParameterSetName = 'FromDestinationDirectory', Mandatory = $true, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] $destinationDirectory
    , [parameter(ParameterSetName = 'FromSourceFiles', Mandatory = $true, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] [object[]]$SourceFiles
    # The remaining parameters are all optional, and belong to all parametersets
    , [parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] $linkFile = 'linkFile.json'
    , [alias('ITypes')]
    [parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)][string[]] $ImageTypes = @('.jpg', '.png', '.img')
    , [parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] $visualSortOrderPattern = '^(?<VisualSortOrder>\d+)\s*(?<Title>.+)\s*$'
    # File Attributes to copy from source image to MediaQuery images and Thumbnail
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $FileAttributesToCopy = @('CreationTimeUTC', 'LastWriteTimeUtc', 'LastAccessTimeUtc')
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string[]] $ExtendedFileAttributesToCopy = @('camera', 'location')
    # Media Queries variables, validations
    #, [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $MediaQueryHighestResolutionFilenameFragment = '-fullres'
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]  $MediaQueryFilenameFragments = @{'-small' = 320; '-medium' = 768; '-large' = 1224; }
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]  $MediaQueryFileSubdirectory = 'MQFiles'

  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

    # ensure the needed functions are loaded from library modules
    if ([string]::IsNullOrWhiteSpace($( Get-Command Get-FileMetaData -ErrorAction SilentlyContinue))) {
      Import-Module ATAP.Utilities.FileIO.PowerShell # this function needs the Get-FileMetaData, Copy-FileAttributes, Copy-ExtendedFileAttributes functions from the ATAP.Utilities.FileIO.PowerShell modules
      if ([string]::IsNullOrWhiteSpace($( Get-Command Get-FileMetaData -ErrorAction SilentlyContinue))) {
        throw 'cannot access function Get-FileMetaData from module ATAP.Utilities.FileIO.PowerShell'
      }
    }

    # In and out directory and file validations
    if (-not (Test-Path -Path $destinationDirectory -PathType Container)) { throw "$destinationDirectory is not a directory" }

    # Valiate the inputs match the inputs expected of the parameter set specified
    $HasCloudHostedImageLinksFilename = $false
    if ($CloudHostedImageLinksFilename) {
      if (Test-Path -Path $CloudHostedImageLinksFilename -PathType leaf OnError=silentlycontinue) { $HasCloudHostedImageLinksFilename = $true }
    }

    # Get all matching FileInfo Properties from the DestinationDirectory and its children
    $ImageTypesPattern = $ImageTypes -join '|'
    $destinationDirectoryFileInfos = Get-ChildItem -r $destinationDirectory | Where-Object { $_.extension -match $ImageTypesPattern }

    # ParameterSetName 'FromDestinationDirectory' must have image files in the destination directory
    if ((-not $HasCloudHostedImageLinksFilename) -and (-not $destinationDirectoryFileInfos)) { { throw "$destinationDirectory has no Links file nor any image files" } }
    # ParameterSetName 'FromSourceFiles' must have image files in the source directory
    #if ((-not $HasCloudHostedImageLinksFilename) -and (-not $CloudHostedImageFileInfos)) { { throw "$destinationDirectory has no Links file nor any image files" } }
    # ParameterSetName 'FromLinksFile' must have a Links file in the DestinationDirectory
    #if ((-not $HasCloudHostedImageLinksFilename) -and (-not $CloudHostedImageFileInfos)) { { throw "$destinationDirectory has no Links file nor any image files" } }

    # Output tests
    # Validate that the $destinationDirectory is writable, the MediaQueryFilesDirectory is writeable, and the
    $testOutFn = Join-Path $destinationDirectory 'test.txt'
    try {
      New-Item $testOutFn -Force -type file >$null   # New-Item honors the WhatIf preference
    }
    catch {
      #Log('Error', "Can't write to file $testOutFn");
      throw "Permission error: Can't write to file $testOutFn"
    }
    # Remove the test file unless Whatif
    if ($PSCmdlet.ShouldProcess(@($testOutFn), "Remove-Item $testOutFn")) {
      Remove-Item $testOutFn -ErrorAction Stop
    }

    # ParameterSetName 'FromSourceImages' accepts input from the pipeline
    $pipelineAccumulater = @()

    # ParameterSetName 'FromLinksFile' rquires a linksFile be present and have at least one record
    $pipelineAccumulater = @()

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
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    # only ParameterSetName 'FromSourceFiles' accepts pipeline input.
    # Accumlate all the SourcFiles here
    #$pipelineAccumulater += $sourceFilee
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    # The $linkFile is the source of truth if it exists, but if it does not exist, create one from the current list of image file name in the $destinationDirectory
    $CloudHostedImageLinks = @()
    $MediaResources = @()
    $CloudHostingImageUniqFileInfos = @();
    if ($HasCloudHostedImageLinksFilename) {
      $CloudHostedImageLinks = Get-Content $CloudHostedImageLinksFilename
      # validate and update as required
    }
    else {
      # There is no CloudHostedImageLinksFilename, so create the data
      # ToDo: parameter sets for "takeitfromthecloudhostingimagepath" and "takeitfromanoriginalsfolder"
      # ParameterSetName = 'FromDestinationDirectory'
      # This region uses the $destinationDirectory as the source of originals.
      # List of unique filenames after stripping off the MediaQueryFilenameFragments keys
      $UniqeFilenames = $destinationDirectoryFileInfos | Get-UniqueFileBasenames -MediaQueryFilenameFragments $MediaQueryFilenameFragments
      # iterate over each unique filename, create a MediaResource object for each, accumulate them all into the $MediaResources collection
      $debugcnt = 0
      $MediaResources = $UniqeFilenames | ForEach-Object {
        $debugcnt++
        if ($debugcnt -gt 1) { Write-Verbose "DEBUG_COUNT : $debugcnt"; return $($CloudHostedImageLinks | ConvertTo-Json); break }

        # Get just the basename fileinfo
        $ufn = $_; $destinationDirectoryFileInfos | Where-Object { $_.basename -eq $ufn } | ForEach-Object {
          $originalImageFileInfo = $_;
          # Get the Visual Sort Order by parsing the filename
          if ($originalImageFileInfo.basename -match $visualSortOrderPattern) {
            $title = $matches.Title
            $visualSortOrder = $matches.VisualSortOrder
          }
          else {
            # ToDo: how to handle files with no VSO number in the basename
            $title = $_.basename
            $visualSortOrder = 999
          }

          # Get the list of Extended Attributes from the original file
          $originalImageMetaData = Get-FileMetaData $originalImageFileInfo
          $originalImageWidth = $originalImageMetaData.Width -replace '[^\d]*(\d+)[^\d]*', '$1'
          # use lib-vip to create a Thumbnail file
          $ThumbnailFilename = $originalImageFileInfo.Basename + '-TH' + $originalImageFileInfo.Extension
          #vips thumbnail_source [descriptor=0] .jpg[Q=90] 128
          #$ThumbnailFileInfo = Get-Item $ThumbnailFilename
          # Create an object that that describes the original file, the Thumbnail file and every media query generated file
          $MediaResource = New-Object PSObject -Property @{
            'Fullname'                   = $originalImageFileInfo.fullname
            'Basename'                   = $originalImageFileInfo.Basename
            'Extension'                  = $originalImageFileInfo.Extension
            'FileHash'                   = $(Get-FileHash -Path $originalImageFileInfo.fullname)
            'Title'                      = $title
            'Description'                = 'Insert Description'
            'VisualSortOrder'            = '{0:d3}' -f $visualSortOrder
            'SharingLinkToOriginalFile'  = ''
            'THFullname'                 = $ThumbnailFileInfo.fullname
            'THBasename'                 = $ThumbnailFileInfo.Basename
            'THExtension'                = $ThumbnailFileInfo.Extension
            'THFileHash'                 = $ThumbnailFileInfo.Hash
            'THTitle'                    = $title
            'THDescription'              = 'Insert Description'
            'THVisualSortOrder'          = '{0:d3}' -f $visualSortOrder
            'SharingLinkToThumbnailFile' = ''
            'MediaQueryFiles'            = @{}
          }
          # Create all of the reduced-size media query images
          $MQPath = Join-Path $originalImageFileInfo.Directory $MediaQueryFileSubdirectory
          # ToDo:  confirm that we have permission to create then write into $MediaQueryFileSubdirectory
          New-Item -ItemType Directory -Force -Path $MQPath > $null
          $mediaQueryFilenameFragments.Keys | ForEach-Object {
            $MQName = $_
            # use the VIP library to create the MediaQuery file
            $infilename = $originalImageFileInfo.fullname
            # add the fragment string to the base
            # ToDo: this will vary by paramter set, the output directory
            $outfilename = Join-Path $MQPath -ChildPath $($originalImageFileInfo.Basename + $MQName + $originalImageFileInfo.Extension)
            Write-Verbose $outfilename
            # update the width and height based on the media query's breakpoints
            # parse the width and height, assumes pixels
            # ToDo: error handline
            $width = $mediaQueryFilenameFragments[$MQName] -replace '[^\d]*(\d+)[^\d]*', '$1'
            # $height = $mediaQueryFilenameFragments[$MQName].Height -replace '[^\d]*(\d+)[^\d]*','$1'
            [double]$scale = $width / $originalImageWidth
            # ToDo: error handling
            if ($PSCmdlet.ShouldProcess(@($infilename, $outfilename, $scale), 'vips.exe resize $infilename $outfilename $scale')) {
              vips.exe resize $infilename $outfilename $scale
              # ToDo: error handling
              $outFileInfo = Get-Item $outfilename
              # Copy the File attributes and Extended Attributes from the original to the MediaQuery copy
              # FileAttributesToCopy
              Copy-FileAttributes -source $MediaResource.FullName -target $outfilename -attr $FileAttributesToCopy
              #Copy-ExtendedFileAttributes -source $MediaResource.FullName -destination $outfilename -attr $ExtendedFileAttributesToCopy
              # Add this media file as an element in the collection held by the origianl record
              $MediaResource.MediaQueryFiles[$_] = New-Object PSObject -Property @{
                'Fullname'                    = $outFileInfo.fullname
                'Basename'                    = $outFileInfo.Basename
                'Extension'                   = $outFileInfo.Extension
                'FileHash'                    = $(Get-FileHash -Path $originalImageFileInfo.fullname)
                'MediaQueryName'              = $MQName
                'Title'                       = $MediaResource.Title
                'Description'                 = $MediaResource.Description
                'VisualSortOrder'             = $MediaResource.VisualSortOrder
                'SharingLinkToMediaQueryFile' = ''
              }
            }
          }
        }
        $MediaResource
      }

      # Create all of the thumbnails in a parallel batch
      #parallel vipsthumbnail --size 720 {} -o 720/%s.jpg ::: *.jpg
      # Get hashes for all of the thumbnails

      # Get the Cloud hosted sharing links to every file
      $MediaResources | ForEach-Object {
        $MediaResource = $_
        # get and store the sharing link for the original
        if ($PSCmdlet.ShouldProcess($MediaResource.Fullname, 'Get-DropBoxSharingLink <target>')) {
          $MediaResource.SharingLinkToOriginalFile = Get-DropBoxSharingLink $MediaResource.Fullname
        }
        # get and store the sharing link for every MediaQuery file
      }




      # Write the imagelinksfile,
      $MediaResources | ConvertTo-Json # | Set-Content $CloudHostedImageLinksFilename
    }

    # Create Thumbnails of requested
    Write-Verbose "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Add-BlogPostImages
#############################################################################

