Function Get-ViewOfProfiles {
gc D:/temp/ProfileFilesOnF.txt |
  %{
    $_ -match '^(.*?)(\d{1,2}\/\d{1,2}\/\d{1,4})' > null
    $fullname = $matches[1]; $lastwritetime = $matches[2]
    if ((Split-Path $fullname -extension) -match '.ps[m]*1') {
      $lines = gc $fullname
      $OutObj = [PSCustomObject]@{
        fullname = $fullname
        leaf = Split-Path $fullname -leaf
        parent    = Split-Path $fullname -parent
        leafbase = Split-Path $fullname -leafbase
        Lastwritetime = [datetime]::Parse($lastwritetime)
        NumLines = $lines.Count
        hash =  (Get-FileHash $fullname).hash
      }
      $OutObj
    }
  }
}
