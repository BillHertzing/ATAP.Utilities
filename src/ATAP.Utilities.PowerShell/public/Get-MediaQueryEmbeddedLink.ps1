

#############################################################################
#region Get-MediaQueryEmbeddedLink
<#
.SYNOPSIS
Gets the embedded links strings for an ATAP MediaResource object
.DESCRIPTION
.PARAMETER MediaResource
This is the ATAP MediaResouce object from which to make the embedding links
.INPUTS
A single MediaResouce object. (pipeline input supported)
.OUTPUTS
A string that can be embedded into a blog post's markdown file
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
Function Get-MediaQueryEmbeddedLink {
  #region FunctionParameters
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)] [object] $MediaResource
    # The remaining parameters are all optional
    , [alias('StillExtensions')]
    [parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)][string[]] $StillImageTypeExtensions = @('.jpg', '.png', '.img')
    , [alias('MovingExtensions')]
    [parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)][string[]] $MovingImageTypeExtensions = @('.mov', '.mpg', '.mp4')
    , [parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] $MovingImageAttributes = @{mov = @{type = 'video/mov';height = 'FrameHeight'; width = 'FrameWidth'  } ; mpg = @{type = 'vidoe/mpg';height = 'FrameHeight'; width = 'FrameWidth'  }; mp4 = @{type = 'video/mp4';height = 'FrameHeight'; width = 'FrameWidth'  } }

    # Media Queries variables, validations
    #, [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] [string] $MediaQueryHighestResolutionFilenameFragment = '-fullres'
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $MediaQueryFilenameFragments = @{'-small' = @{px = 320;size=400}; '-medium' = @{px = 768;size=700}; '-large' = @{px = 1224;size=1200}; }


  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

    # Create a pattern to match the extensions of still images that this function supports
    $StillImageTypeExtensionPattern = $StillImageTypeExtensions -join '|'
    $MovingImageTypeExtensionPattern = $MovingImageTypeExtensions -join '|'

    # # ToDo: make PS Types or objects, or reference a common types file
    # $results = New-Object PSObject -Property @{
      # EveryLink                 = @{} # Every Still Image Link
      # EveryLinkStringArray      = @()
      # GalleryAllImagesAsArray   = @()
      # GalleryAllImagesAsString  = ''
      # Videos                    = @{} #  Every Moving Image Link
      # EveryVideoLinkStringArray = @()
      # VideosAllAsString         = ''
    # }
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    # $MediaResource = New-Object PSObject -Property @{
      # 'Fullname'                   = $originalImageFileInfo.fullname
      # 'Basename'                   = $originalImageFileInfo.Basename
      # 'Extension'                  = $originalImageFileInfo.Extension
      # 'FileHash'                   = $(Get-FileHash -Path $originalImageFileInfo.fullname)
      # 'Title'                      = $title
      # 'Description'                = 'Insert Description'
      # 'VisualSortOrder'            = '{0:d3}' -f $visualSortOrder
      # 'SharingLinkToOriginalFile'  = ''
      # 'THFullname'                 = $ThumbnailFileInfo.fullname
      # 'THBasename'                 = $ThumbnailFileInfo.Basename
      # 'THExtension'                = $ThumbnailFileInfo.Extension
      # 'THFileHash'                 = $ThumbnailFileInfo.Hash
      # 'THTitle'                    = $title
      # 'THDescription'              = 'Insert Description'
      # 'THVisualSortOrder'          = '{0:d3}' -f $visualSortOrder
      # 'SharingLinkToThumbnailFile' = ''
      # 'MediaQueryFiles'            = @{}
    # }

      # $MediaResource.MediaQueryFiles[$_] = New-Object PSObject -Property @{
      #   'Fullname'                    = $outFileInfo.fullname
      #   'Basename'                    = $outFileInfo.Basename
      #   'Extension'                   = $outFileInfo.Extension
      #   'FileHash'                    = $(Get-FileHash -Path $originalImageFileInfo.fullname)
      #   'MediaQueryName'              = $MQName
      #   'Title'                       = $MediaResource.Title
      #   'Description'                 = $MediaResource.Description
      #   'VisualSortOrder'             = $MediaResource.VisualSortOrder
      #   'SharingLinkToMediaQueryFile' = ''
      # }


    $resultString = '<img srcset="'

    # Media queries require that the srcset be ordered by break size ascending

    $addComma = ''
    $mediaQueryFilenameFragments.GetEnumerator() |sort-object  {$_.value.size} | ForEach-Object {
      $MQName = $_.Name
      $pxBreak = $($MediaQueryFilenameFragments[$MQName]).px
      $sizeBreak = $($MediaQueryFilenameFragments[$MQName]).size
      $mqf = $MediaResource.MediaQueryFiles
      $mqf2 = $mqf.$MQName
      $sl = $mqf2.SharingLinkToMediaQueryFile
      write-verbose "$sl"
      $resultString += [environment]::NewLine + $addcomma + $MediaResource.MediaQueryFiles.$MQName.SharingLinkToMediaQueryFile + ' ' + $sizeBreak + 'w'
      $addComma = ','
    }
    # two blank lines
    $resultString += '"' + [environment]::NewLine * 2
    $resultString += 'sizes="'
    $addComma = ''
    # Media queries require that the sizes be ordered by break size descending
    $mediaQueryFilenameFragments.GetEnumerator() |sort-object  {$_.value.size} -Descending | ForEach-Object {
      $MQName = $_.Name
      $pxBreak = $($MediaQueryFilenameFragments[$MQName]).px
      $sizeBreak = $($MediaQueryFilenameFragments[$MQName]).size
      $resultString += [environment]::NewLine +  $addcomma + '(min-width: ' + $pxBreak + 'px) ' + $sizeBreak + 'px'
      $addComma = ','
    }
    # output the result string on down the pipeline
    $resultString
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
#   $str = @'
# <picture>
#     <source media="{min-width: 1280}"
#       srcset=
#     />

#     <img src = "srcreplacementpattern" alt = "altreplacementpattern"
#   </picture>
# '@
#   $str = @'
#   <img srcset="
#   srcreplacementpattern-mqreplacementpattern.srcextensionreplacement 320w,
#                 medium-car-image.jpg 768w,
#                 large-car-image.jpg 1224w
#   "
#     src = "srcreplacementpattern" alt = "altreplacementpattern"
#     >
# '@
    Write-Verbose "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Get-MediaQueryEmbeddedLink
#############################################################################
