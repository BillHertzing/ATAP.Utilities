function perftest {
  param (
    [string[]] $path = 'c:\dropbox\photos'
    , [string] $outputPath = 'D:\temp\PlaygroundImageMetadata\t1.yml'
    , [int] $limit = 100000
    , [string[]] $extension = ('jpg', 'png', 'heic')
  )
  # 'c:\dropbox\photos\[abcdefghijklmnopqrstuvwxyz]*', 'c:\dropbox\photos\19*', 'c:\dropbox\photos\200*', 'c:\dropbox\photos\201*', 'c:\dropbox\photos\202[012]*', 'C:\Dropbox\Camera Uploads','C:\Dropbox\Camera Uploads\*'
  $ImageMetadata = [System.Collections.Generic.List[hashtable]]::new()
  $completepath = @()
  foreach ($p in $path) {
    foreach ($ext in $extension) {
      $completepath += Join-Path $p "*.$ext"
    }
  }
  $timeForParsingAndStoringMetadata = Measure-Command {
    $( Get-ChildItem -r $completepath |
      Select-Object -First 100000 |
      Get-FileMetadata).metadata | ConvertTo-Yaml > $OutputPath }
  $memoryUsageMBForParsingAndStoringMetadata = [System.Diagnostics.Process]::GetCurrentProcess().PrivateMemorySize64 / 1MB
  $timeForReadingMetadataFromFile = Measure-Command {
    $MetadataHashtables = Get-Content $OutputPath -Raw | ConvertFrom-Yaml
    for ($MetadataHashtablesIndex = 0; $MetadataHashtablesIndex -lt $MetadataHashtables.Count; $MetadataHashtablesIndex++) {
      $MetadataHashtable = $MetadataHashtables[$MetadataHashtablesIndex]
      $ImageMetadata.Add($MetadataHashtable)
    }
  }
  $totalMemoryUsageMB = [System.Diagnostics.Process]::GetCurrentProcess().PrivateMemorySize64 / 1MB
  $result = [PSCustomObject]@{
    TimeForParsingAndStoringMetadata          = $timeForParsingAndStoringMetadata.Minutes
    TimeForReadingMetadataFromFile            = $timeForReadingMetadataFromFile.Minutes
    TotalTime                                 = $timeForParsingAndStoringMetadata.Minutes + $timeForReadingMetadataFromFile.Minutes
    NumberOfFiles                             = $ImageMetadata.count
    MemoryUsageMBForParsingAndStoringMetadata = $memoryUsageMBForParsingAndStoringMetadata
    MemoryUsageMBForReadingMetadataFromFile   = $totalMemoryUsageMB - $memoryUsageMBForParsingAndStoringMetadata
    TotalMemoryUsageMB                        = $totalMemoryUsageMB
    Path                                      = $path
    Extension                                 = $extension
    OutputPath                                = $outputPath
  }
  Write-Output $result
}
