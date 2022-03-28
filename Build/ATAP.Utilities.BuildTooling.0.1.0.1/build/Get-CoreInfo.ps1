Function Get-CoreInfo {
  $pathToDotNet = "$env:programW6432/dotnet"
  Write-Host "pathToDotNet = $pathToDotNet"
  if (Test-Path $pathToDotNet) {
    try {

      [Collections.Generic.List[string]] $info = dotnet --info

      $versionLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -like '*version*:*' } )

      $runtimes = (ls "$pathToDotNet/shared/Microsoft.NETCore.App").Name | Out-String

      $sdkVersion = dotnet --version

      $fhVersion = (($info[$versionLineIndex]).Split(':')[1]).Trim()

      return "SDK version: `r`n$sdkVersion`r`n`r`nInstalled runtime versions:`r`n$runtimes`r`nFramework Host:`r`n$fhVersion"
    }
    catch { # if an exception ocurrs
      # handle the exception
      $where = $PSItem.InvocationInfo.PositionMessage
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      Throw "Get-CoreInfo failed with $FailedItem : $ErrorMessage at `n $where."
    } 
  }
}
else {
  Write-Host "No SDK installed at $pathToDotNet"
  return ''
}
}
Get-CoreInfo


