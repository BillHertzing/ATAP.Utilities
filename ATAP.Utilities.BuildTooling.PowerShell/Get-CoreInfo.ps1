Function Get-CoreInfo {
    if(Test-Path "$env:programfiles/dotnet/"){
        try{

            [Collections.Generic.List[string]] $info = dotnet --info
            $DotNetCoreSDKVersionLineIndex = $info.FindIndex( {$args[0].ToString().ToLower() -like "^\s+version:\s+*"} )
            $DotNetCoreSDKVersion = (($info[$DotNetCoreSDKVersionLineIndex]).Split(':')[1]).Trim()
            $OSVersionLineIndex = $info.FindIndex( {$args[0].ToString().ToLower() -like "^\s+OS\s+\s+version:\s+*"} )
            $OSVersion = (($info[$OSVersionLineIndex]).Split(':')[1]).Trim()
            $runtimes = (ls "$env:programfiles/dotnet/shared/Microsoft.NETCore.App").Name | Out-String
            $object = New-Object -TypeName pscustomobject -Property (@{
              '$DotNetCoreSDKVersion'=$DotNetCoreSDKVersion;
              'OSVersion'=$OSVersion;
              'BIOSSerial'=$bios.SerialNumber
              })

            return  $object
        }
        catch{
            $errorMessage = $_.Exception.Message

            Write-Host "Something went wrong`r`nError: $errorMessage"
        }
    }
    else{    
        Write-Host 'No SDK installed'
        return ""
    }
}
Get-CoreInfo

