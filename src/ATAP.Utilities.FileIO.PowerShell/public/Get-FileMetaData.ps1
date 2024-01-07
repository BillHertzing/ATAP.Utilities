function Get-FileMetaData {
  <#
  .SYNOPSIS
  Small function that gets metadata information from file providing similar output to what Explorer shows when viewing file

  .DESCRIPTION
  Small function that gets metadata information from file providing similar output to what Explorer shows when viewing file

  .PARAMETER File
  FileName or FileObject

  .EXAMPLE
  Get-ChildItem -Path $Env:USERPROFILE\Desktop -Force | Get-FileMetaData | Out-HtmlView -ScrollX -Filtering -AllProperties

  .EXAMPLE
  Get-ChildItem -Path $Env:USERPROFILE\Desktop -Force | Where-Object { $_.Attributes -like '*Hidden*' } | Get-FileMetaData | Out-HtmlView -ScrollX -Filtering -AllProperties

  .NOTES
  Windows only, not suitable for Linux or WSL

  .Attribution https://evotec.xyz/getting-file-metadata-with-powershell-similar-to-what-windows-explorer-provides/
  #>
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'PathAsStringsParameterSet'  )]
  param (
    [parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)]
    [Object[]] $Path
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [int] $FileMetadataBlockSize
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [switch] $GetFileSignatureAsMetadata
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [switch] $useEnums
  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $originalPSBoundParameters = $PSBoundParameters # to allow debugging
    # requires Get-ParameterValueFromNeoConfigurationRoot
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
    # import ATAP.Utilities.Powershell

    # requires ATAP.Utilities.Images.Enumerations
    Add-Type -Path $(Join-Path $env:localappdata 'PackageManagement' 'NuGet' 'Packages' 'ATAP.Utilities.Images.Enumerations.1.0.0' 'lib' 'net7.0' 'ATAP.Utilities.Images.Enumerations.dll')

    if ($Path -or $FileMetadataBlockSize -or $GetFileSignatureAsMetadata ) {
      # Not from pipeline
      $noArgumentsSupplied = $false
      if (-not $path) {
        $message = 'Path is required on the command line if any of the remainder arguments appear on the command line'
        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
      $GetFileSignatureAsMetadata = Get-ParameterValueFromNeoConfigurationRoot 'GetFileSignatureAsMetadata' $global:configRootKeys['GetFileSignatureAsMetadataConfigRootKey'] $originalPSBoundParameters
      $FileMetadataBlockSize = Get-ParameterValueFromNeoConfigurationRoot 'FileMetadataBlockSize' $global:configRootKeys['FileMetadataBlockSizeConfigRootKey'] $originalPSBoundParameters
    }
    else {
      $noArgumentsSupplied = $true
      $GetFileSignatureAsMetadata = Get-ParameterValueFromNeoConfigurationRoot 'GetFileSignatureAsMetadata' $global:configRootKeys['GetFileSignatureAsMetadataConfigRootKey']
      $FileMetadataBlockSize = Get-ParameterValueFromNeoConfigurationRoot 'FileMetadataBlockSize' $global:configRootKeys['FileMetadataBlockSizeConfigRootKey']
    }

    # ToDO: Add all code necessary to make this available in $global:settings
    $exifToolPath = 'C:\ProgramData\chocolatey\bin\exiftool.exe'
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    # Create a List of FileInfo objects and a list of hashtables
    # ToDo: replace hashtable with an ExifInfo data type
    $script:blockOfPaths = [System.Collections.Generic.List[string]]::new()
    $script:blockOfMetadataObjects = [System.Collections.Generic.List[hashtable]]::new()
    $script:toolArgs = [System.Collections.Generic.List[string]]::new()



    function DispatchToBlock {
      param (
        [object] $obj
      )
      # Powershell implements short-circuiting for boolean operators
      $typed = $false
      if ($obj -is [string]) {
        $typed = $true
        # If obj is string, treat it as dirty, clean it, use it as a path
        # ToDo: Security: fix needed to test external input to the program/process space
        # ToDo: security: make sure this obj can't be spoofed or used maliciously. Need to secure against exploits in underlying
        $script:blockOfPaths.Add($obj)
      }
      if ($(-not $typed) -and $($obj -is [System.IO.FileInfo])) {
        $script:blockOfPaths.Add($obj.fullname)
        $typed = $true
      }
      if ($typed) {
        # If the block of paths has reached the BlockSize limit, process all files in the block.
        if ($script:blockOfPaths.count -ge $FileMetadataBlockSize ) {
          ProcessBlock
        }
      }
      else {
        if ($obj -is [string[]]) {
          $typed = $true
          for ($objIndex = 0; $objIndex -lt $obj.Count; $objIndex++) {
            $script:blockOfPaths.Add($obj[$objIndex])
            # If the block of paths has reached the BlockSize limit, process all files in the block.
            if ($script:blockOfPaths.count -ge $FileMetadataBlockSize ) {
              ProcessBlock
            }
          }
        }
        if (-not $typed -and $($obj -is [System.IO.FileInfo[]])) {
          $typed = $true
          for ($objIndex = 0; $objIndex -lt $obj.Count; $objIndex++) {
            $script:blockOfPaths.Add($obj[$objIndex])
            if ($script:blockOfPaths.count -ge $FileMetadataBlockSize ) {
              ProcessBlock
            }
          }
        }
      }
      if (-not $typed) {
        $message = "The argument is of type $($obj.gettype()) and is not supported. the argument must be a string or a fileinfo, an array of either, or a PSCustomObject/hashtable/.Net type having a Path property"
        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
    }
    function ProcessBlock {
      InternalGetBlockMetadata
      # write the data to output
      for ($BlockOfPathsIndex = 0; $BlockOfPathsIndex -lt $script:blockOfPaths.Count; $BlockOfPathsIndex++) {
        Write-Output  @{
          Path     = $script:blockOfPaths[$BlockOfPathsIndex]
          Metadata = $script:blockOfMetadataObjects[$BlockOfPathsIndex]
        }
      }
      $script:BlockOfPaths.Clear()
      $script:blockOfMetadataObjects.Clear()
    }
    function InternalGetBlockMetadata {
      Write-PSFMessage -Level Debug -Message $("BlockOfPaths $script:blockOfPaths.ToString()")
      for ($BlockOfPathsIndex = 0; $BlockOfPathsIndex -lt $script:blockOfPaths.Count; $BlockOfPathsIndex++) {
        $SingleFilePath = $script:blockOfPaths[$BlockOfPathsIndex]
        # Wrap in a try/catch block and accumulate errors
        if (Test-Path -Path $SingleFilePath -PathType Leaf) {

        }
        elseif (Test-Path -Path $SingleFilePath -PathType Container  ) {
          # ToDo: add feature to parse directories (a recurse parameter?)
          $message = "Directories are not supported. Skipping $SingleFilePath."
          Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
          # toDo catch the errors, add to 'Problems'
          Throw $message
        }
      }

      $MetaDataObject = [ordered]::new()
      # use the exiftool, get every metadatfield it returns
      $script:toolArgs.Add('-all')
      # ToDo: add the ability to specify an array of property names and fetch just those
      # foreach ($enum in [Enum]::GetValues([ATAP.Utilities.Images.Enumerations.GPSMetadataEnums])) {
      #   [void]$sb.Append('-' + $enum + ' ' )
      # }
      # $script:toolArgs = $sb.ToString()
      # [void] $sb.Clear()
      # combine all the file
      $script:toolArgs.Add($script:blockOfPaths)
      # for ($blockOfPathsIndex = 0; $blockOfPathsIndex -lt $script:blockOfPaths.Count; $blockOfPathsIndex++) {
      #   $script:toolArgs.Add('"' + $blockOfPaths[$blockOfPathsIndex] + '"')
      #   $script:toolArgs.Add('"' + $blockOfPaths[$blockOfPathsIndex] + '"')
      # }
      # ToDo: wrap in try/catch block and handle errors
      $exifInfo = & $exifToolPath $script:blockOfPaths
      $script:toolArgs.clear

      # Iterate through each line in the ExifTool output
      foreach ($line in $exifInfo) {
        # If a line starts with "========", it indicates the start of a new image data
        if ($line -match '^========') {
          # If there is existing data for the current image, add it to the CSV data array
          if ($currentImageData.Count -gt 0) {
            $script:blockOfMetadataObjects.Add($currentImageData)
          }
          # Clear the current image data to start collecting data for the next image
          $currentImageData = @{}
        }
        else {
          # Split the line into key and value using the first colon as a delimiter
          $splitLine = $line -split ':', 2
          if ($splitLine.Length -eq 2) {
            $key = $splitLine[0].Trim()
            $value = $splitLine[1].Trim()
            # Add the key and value to the current image data
            try {
            $currentImageData[$key] = $value
            }catch {
              $message ='nope'
              Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
              # toDo catch the errors, add to 'Problems'
              Throw $message

            }
          }
        }
      }

      # If there is remaining data for the last image, add it to the CSV data array
      if ($currentImageData.Count -gt 0) {
        $script:blockOfMetadataObjects.Add($currentImageData)
      }


      # ToDO: populate a exifInfo data object-j $SingleFilePath
      # ToDo: populate MetadataObject with all exifInfo fields
      # $MetadataObject['exifInfo'] = $exifInfo
      # if ($GetFileSignatureAsMetadata) {
      #   $DigitalSignature = Get-AuthenticodeSignature -FilePath $SingleFilePath
      #   $MetaDataObject['SignatureCertificateSubject'] = $DigitalSignature.SignerCertificate.Subject
      #   $MetaDataObject['SignatureCertificateIssuer'] = $DigitalSignature.SignerCertificate.Issuer
      #   $MetaDataObject['SignatureCertificateSerialNumber'] = $DigitalSignature.SignerCertificate.SerialNumber
      #   $MetaDataObject['SignatureCertificateNotBefore'] = $DigitalSignature.SignerCertificate.NotBefore
      #   $MetaDataObject['SignatureCertificateNotAfter'] = $DigitalSignature.SignerCertificate.NotAfter
      #   $MetaDataObject['SignatureCertificateThumbprint'] = $DigitalSignature.SignerCertificate.Thumbprint
      #   $MetaDataObject['SignatureStatus'] = $DigitalSignature.Status
      #   $MetaDataObject['IsOSBinary'] = $DigitalSignature.IsOSBinary
      # }

    }
  }

  Process {
    if ($noArgumentsSupplied) {
      # none of the cmdlets arguments have any values passed
      # possibly called from pipeline, either by property value, or just a standalone call expecting to use all default values
      if ($input.Count) {
        # called from a pipeline
        foreach ($obj in $input) {
          if ($obj.PSobject.Properties.Name -notcontains 'Path') {
            # $obj is not a PSCustomObject with a property named Paths, so send it on to DispatchToBlock for further type checking and processing
            DispatchToBlock $obj
          }
          else {
            # the input is a PSobject with a property named Paths
            # deconstruct the pipeline object's properties
            $PropertyNames = $obj.PSobject.Properties.Name
            for ($PropertyNamesIndex = 0; $PropertyNamesIndex -lt $PropertyNames.Count; $PropertyNamesIndex++) {
              $PropertyName = $PropertyNames[$PropertyNamesIndex]
              switch ($PropertyName) {
                'Path' { $Path = $obj.PSobject.Properties['Paths'].value; break }
                'GetFileSignatureAsMetadata' { $GetFileSignatureAsMetadata = $obj.PSobject.Properties['GetFileSignatureAsMetadata'].value; break }
                'FileMetadataBlockSize' { $FileMetadataBlockSize = $obj.PSobject.Properties['FileMetadataBlockSize'].value; break }
                'PassThru' { $PassThru = $obj.PSobject.Properties['PassThru'].value; break }
                'computerNames' { $computerNames = $obj.PSobject.Properties['computerNames'].value; break }
                default { # ignore any property names that are not parameters of this cmdlet}
                }
              }
            }
            # send $Path on to DispatchToBlock for further type checking and processing
            DispatchToBlock $Path
          }
        }
      }
      else {
        $message = 'No arguments on the command line and nothing supplied via pipeline'
        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
    }
    else {
      # the path argument is not null
      # send $Path on to DispatchToBlock for further type checking and processing
      DispatchToBlock $Path
    }
  }

  # $ShellApplication = New-Object -ComObject Shell.Application
  # $ShellFolder = $ShellApplication.Namespace($fileInfo.Directory.FullName)
  # $ShellFile = $ShellFolder.ParseName($fileInfo.Name)
  # $MetaDataProperties = [ordered] @{}
  # if ($useEnums) {

  #   $gpsMetadata = $ShellFolder.GetDetailsOf($ShellFile, 4) # Not the right index

  #   $hasdata = @()
  #   $noData = @()

  #   0..500 | % {
  #     if ($($ShellFolder.GetDetailsOf($ShellFile, $_))) { $hasdata += $_ } else { $noData += $_ }
  #   }
  #   foreach ($d in $hasdata) { Write-Output $('{0:D3} {1} = {2};  ' -f $d, $($ShellFolder.GetDetailsOf($null, $d)), $($ShellFolder.GetDetailsOf($ShellFile, $d))) }
  #   Write-Output "empty fields $('*' * 50)"
  #   foreach ($d in $noData) { if ($($ShellFolder.GetDetailsOf($null, $d))) { Write-Output $('{0:D3} {1} is empty;  ' -f $d, $($ShellFolder.GetDetailsOf($null, $d))) } }
  #   # use the exiftool
  #   foreach ($enum in [Enum]::GetValues([ATAP.Utilities.Images.Enumerations.GPSMetadataEnums])) {
  #     [void]$sb.Append('-' + $enum + ' ' )
  #   }
  #   $toolArgs = $sb.ToString()
  #   [void] $sb.Clear()
  #   $gpsInfo = & $exifToolPath $toolArgs -j $path
  #   Write-Output $gpsInfo

  #   foreach ($enum in [Enum]::GetValues([ATAP.Utilities.Images.Enumerations.ImageMetadataEnums])) {
  #     Write-Output "$enum = $([int][ATAP.Utilities.Images.Enumerations.ImageMetadataEnums]::$enum)"
  #     Write-Output $('{0:D3} {1};  ' -f $_, $($ShellFolder.GetDetailsOf($null, $_)))
  #     $DataValue = $ShellFolder.GetDetailsOf($null, $([int][ATAP.Utilities.Images.Enumerations.ImageMetadataEnums]::$enum))
  #     $PropertyValue = (Get-Culture).TextInfo.ToTitleCase($DataValue.Trim()).Replace(' ', '')
  #     $MetaDataProperties[$enum] = $PropertyValue
  #   }
  #   return
  # }
  # else {
  #   0..400 | ForEach-Object -Process {
  #     $DataValue = $ShellFolder.GetDetailsOf($null, $_)
  #     $PropertyValue = (Get-Culture).TextInfo.ToTitleCase($DataValue.Trim()).Replace(' ', '')
  #     if ($PropertyValue -ne '') {
  #       $MetaDataProperties["$_"] = $PropertyValue
  #     }
  #   }
  #   foreach ($Key in $MetaDataProperties.Keys) {
  #     $Property = $MetaDataProperties[$Key]
  #     $Value = $ShellFolder.GetDetailsOf($ShellFile, [int] $Key)
  #     if ($Property -in 'Attributes', 'Folder', 'Type', 'SpaceFree', 'TotalSize', 'SpaceUsed') {
  #       continue
  #     }
  #     If (($null -ne $Value) -and ($Value -ne '')) {
  #       $MetaDataObject["$Property"] = $Value
  #     }
  #   }
  # }
  # if ($fileInfo.VersionInfo) {
  #   $SplitInfo = ([string] $fileInfo.VersionInfo).Split([char]13)
  #   foreach ($Item in $SplitInfo) {
  #     $Property = $Item.Split(':').Trim()
  #     if ($Property[0] -and $Property[1] -ne '') {
  #       $MetaDataObject["$($Property[0])"] = $Property[1]
  #     }
  #   }
  # }
  # $MetaDataObject['Attributes'] = $fileInfo.Attributes
  # $MetaDataObject['IsReadOnly'] = $fileInfo.IsReadOnly
  # $MetaDataObject['IsHidden'] = $fileInfo.Attributes -like '*Hidden*'
  # $MetaDataObject['IsSystem'] = $fileInfo.Attributes -like '*System*'


  End {
    # handle any files left in the block accumulator
    if ($script:blockOfPaths.count ) {
      ProcessBlock
    }
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}

