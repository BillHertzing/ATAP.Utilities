Function Get-CoreInfo {
    if(Test-Path "$env:programfiles/dotnet/"){
        try{

            [Collections.Generic.List[string]] $info = dotnet --info

            # the line after the line containing this string holds thhe version
            $DotNetCoreSDKVersionLineIndex = $info.FindIndex( {$args[0].ToString().ToLower() -like ".NET Core SDK (reflecting any global.json):"} ) + 1
            # to the right of the colon and trimmed
            $DotNetCoreSDKVersion = (($info[$DotNetCoreSDKVersionLineIndex]).Split(':')[1]).Trim()
            $OSVersionLineIndex = $info.FindIndex( {$args[0].ToString().ToLower() -like "^\s+OS\s+\s+version:\s+*"} )
            $OSVersion = (($info[$OSVersionLineIndex]).Split(':')[1]).Trim()

            # the lines after the line containing this string holds the installed runtimes
            $DotNetCoreSDKVersionLineIndex = $info.FindIndex( {$args[0].ToString().ToLower() -like ".NET Core runtimes installed:"} ) + 1
            $runtimes = 

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

