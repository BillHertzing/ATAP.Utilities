

Function New-InstanceCopyFile {
  
  Param(
      [ComputerType]$Type

  )
  [Computer]::New($Type)
}
