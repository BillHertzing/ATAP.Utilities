

#############################################################################
#region Create-BlogPostImages
<#
.SYNOPSIS
Orchestrates the steps needed to create image files in a cloud hosting provider for blog posts
.DESCRIPTION
Creates a persistence file listing all the images in a post. Adds title and description for each image, and lists the media query versions for each file
.PARAMETER CloudHostingProviderImageDirectoryPath
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
Function Create-BlogPostImages {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  # Need two parameter sets, one with an original image array, one without
  param (
    [alias('CHPIPath')]
    [parameter(Mandatory = $true, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] $CloudHostingProviderImageDirectoryPath
    , [alias('LinkFN')]
    [parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] $CloudHostedImageLinksFilenamePath = 'CloudHostingLinks.csv'
    , [alias('ITypes')]
    [parameter(Mandatory = $false, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)][string] $ImageTypesPattern = '(.jpg|.png|.img)'
    , [parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] $OriginalImage
    , [alias('ExAt')]
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string[]] $ExtendedAttributes = @('LastWriteTime', 'LastWriteTimeUTC')
    # Media Queries variables, validations
    #, [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $MediaQueryHighestResolutionFilenameFragment = '-fullres'
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]  $MediaQueryFilenameFragments = @{'-small' = 320; '-medium' = 768; '-large' = 1224;  }
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $FileAttributesToCopy = @('CreationTimeUTC', 'LastWriteTimeUtc')
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    ########################################
    #region local private function
    function Private:Get-UniqueFileBasenames {
      [CmdletBinding()]
      param (
        [parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]  $inFileInfo
      )
      BEGIN {
        $acc = @()
      }
      PROCESS { $acc += $inFileInfo }
      END {
        $pattern = $MediaQueryFilenameFragments.Keys -join '|'
        $acc | Select-Object -ExpandProperty Basename | ForEach-Object{$_ -replace $pattern, ''} | Sort-Object -Uniq
      }
    }

    #endregion local private function

    $DebugPreference = 'Continue' # remove before end of beta lifecycle stage
    $VerbosePreference = 'Continue' # remove before end of beta lifecycle stage

    # ensure the needed librarys are loaded
    ipmo C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FIleIO\ATAP.Utilities.FileIO.PowerShell\ATAP.Utilities.FileIO.PowerShell.psm1

    # In and out directory and file validations
    if (-not (Test-Path -Path $CloudHostingProviderImageDirectoryPath -PathType Container)) { throw "$CloudHostingProviderImageDirectoryPath is not a directory" }
    $HasCloudHostedImageLinksFilename = $false
    if ($CloudHostedImageLinksFilename) {
      if (Test-Path -Path $CloudHostedImageLinksFilename -PathType leaf OnError=silentlycontinue) { $HasCloudHostedImageLinksFilename = $true }
    }
    # Always going to need the list of any CloudHostedImageFilenames
    $CloudHostedImageFileInfos = Get-ChildItem $CloudHostingProviderImageDirectoryPath | Where-Object { $_.suffix -match $ImageTypePattern }

    if ((-not $HasCloudHostedImageLinksFilename) -and (-not $CloudHostedImageFileInfos)) { { throw "$CloudHostingProviderImageDirectoryPath has no Links file nor any image files" } }

    # Output tests
    # Validate that the $CloudHostingProviderImageDirectoryPath is writable
    $testOutFn = Join-Path $CloudHostingProviderImageDirectoryPath 'test.txt'
    try { New-Item $testOutFn -Force -type file >$null }
    catch {
      #Log('Error', "Can't write to file $testOutFn");
      throw "Permission error: Can't write to file $testOutFn"
    }
    # Remove the test file
    Remove-Item $testOutFn

    # Image Hosting Solution Global variables, validations
    #$mediaQueryHighestResolutionFilenameFragment = '-fullres'
    #$mediaQueryFilenameFragments = ('-small', '-medium', '-large', $mediaQueryHighestResolutionFilenameFragment)
    #$mediaQueryFilenameFragmentsPattern = $MediaQueryFilenames -join '|'

    $results = @{}
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
    # The $CloudHostedImageLinksFilenamePath is the source of truth if it exists, but if it does not exist, create one from the current list of image file name in the $CloudHostingProviderImageDirectoryPath
    $CloudHostedImageLinks = @()
    $CloudHostingImageUniqFileInfos = @();
    if ($HasCloudHostedImageLinksFilename) {
      $CloudHostedImageLinks = Get-Content $CloudHostedImageLinksFilename
      # validate and update as required
    }
    else {
      # Therer is no CloudHostedImageLinksFilename, so create the data
      # ToDo: parameter sets for "takeitfromthecloudhostingimagepath" and "takeitfromanoriginalsfolder"
      # This region uses the $CloudHostingProviderImageDirectoryPath as the source of originals.
      # List of unique filenames after stripping off the MediaQueryFilenameFragments keys
      $CloudHostingImageUniqFilenames = $CloudHostedImageFileInfos | Get-UniqueFileBasenames
      # iterate over each unique filename
      $CloudHostedImageLinks = $CloudHostingImageUniqFilenames | ForEach-Object {
        # Get just the basename fileinfo
        $ufn = $_; $CloudHostedImageFileInfos | Where-Object { $_.basename -eq $ufn } | ForEach-Object {
          $originalImageFileInfo = $_;
          # Get the list of Extended Attributes from the original file
          $originalImageMetaData = Get-FileMetaData $originalImageFileInfo
          $originalImageWidth = $originalImageMetaData.Width -replace '[^\d]*(\d+)[^\d]*', '$1'
          # use lib-vip to create a Thumbnail file
          $ThumbnailFilename = $originalImageFileInfo.Basename + '-TH' + $originalImageFileInfo.Extension
          #vips thumbnail_source [descriptor=0] .jpg[Q=90] 128
          #$ThumbnailFileInfo = Get-Item $ThumbnailFilename
          # Create an object that that describes the original file, the Thumbnail file and every media query generated file
          $MediaResource = New-Object PSObject -Property @{
            'Fullname'               = $originalImageFileInfo.fullname
            'Basename'               = $originalImageFileInfo.Basename
            'Extension'              = $originalImageFileInfo.Extension
            'FileHash'               = $originalImageFileInfo.Hash
            'Title'                  = 'Insert Title'
            'Description'            = 'Insert Description'
            'VisualSortOrder'        = '{0:d3}' -f 0
            'DropBoxLinkToOriginal'  = ''
            'THFullname'             = $ThumbnailFileInfo.fullname
            'THBasename'             = $ThumbnailFileInfo.Basename
            'THExtension'            = $ThumbnailFileInfo.Extension
            'THFileHash'             = $ThumbnailFileInfo.Hash
            'THTitle'                = 'Insert Title'
            'THDescription'          = 'Insert Description'
            'THVisualSortOrder'      = '{0:d3}' -f 0
            'DropBoxLinkToThumbnail' = ''
            'MediaQueryFiles'        = @{}
          }
          # Create all of the reduced-size media query images
          $mediaQueryFilenameFragments.Keys | ForEach-Object {
            $MQName = $_
            # use the VIP library to create the MediaQuery file
            $infilename = $originalImageFileInfo.fullname
            # add the fragment string to the base
            # ToDo: this will vary by paramter set, the output directory
            $outfilename = Join-Path $originalImageFileInfo.Directory ($originalImageFileInfo.Basename + $MQName + $originalImageFileInfo.Extension)
            # update the width and height based on the media query's breakpoints
            # parse the width and height, assumes pixels
            # ToDo: error handline
            $width = $mediaQueryFilenameFragments[$MQName] -replace '[^\d]*(\d+)[^\d]*', '$1'
            # $height = $mediaQueryFilenameFragments[$MQName].Height -replace '[^\d]*(\d+)[^\d]*','$1'
            [double]$scale = $width / $originalImageWidth
            # ToDo: error handling
            vips.exe resize $infilename $outfilename $scale
            # ToDo: error handling
            $outFileInfo = Get-Item $outfilename
            # Copy the original's attribute to the new MediaQuery fileinfo as specified in FileAttributesToCopy
           #Copy-FileTimeAttributes -sourcefiles $originalImageFileInfo -targetfiles $outFileInfo
            # Copy the original's ExtendedAttributes to the new MediaQuery fileinfo as specified in FileExtendedAttributesToCopy
            $FileExtendedAttributesToCopy | ForEach-Object { $attr = $_
              "$attr"
            }
            # $ExtendedAttributes = $hash.OriginalImageExtendedAttributes
            # Add this media file as an element in the collection held by the origianl record
            $MediaResource.MediaQueryFiles[$_] = New-Object PSObject -Property @{
              'Fullname'              = $outFileInfo.fullname
              'Basename'              = $outFileInfo.Basename
              'Extension'             = $outFileInfo.Extension
              'FileHash'              = $outFileInfo.Hash
              'MediaQueryName'        = $MQName
              'Title'                 = $MediaResource.Title
              'Description'           = $MediaResource.Description
              'VisualSortOrder'       = $MediaResource.VisualSortOrder
              'DropBoxLinkToOriginal' = ''
            }
            # Get the list of Extended Attributes from the original file
          }
        }
      }
    }
    # Create Thumbnails of requested
    #parallel vipsthumbnail --size 720 {} -o 720/%s.jpg ::: *.jpg
    Write-Verbose "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Create-BlogPostImages
#############################################################################

