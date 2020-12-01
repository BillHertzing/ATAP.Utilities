#
# Set_PerceivedTypeInRegistryForPreviewPane.ps1
#
[CmdletBinding(SupportsShouldProcess=$true)]
param (
    
)

function Set_PerceivedTypeInRegistryForPreviewPane {
[CmdletBinding(SupportsShouldProcess=$true)]
param (

)
    $suffixes= @('.ps1','.psm1','.targets','.props','.psproj','.csproj','.sln')
    $RegHiveType = [Microsoft.Win32.RegistryHive]::"ClassesRoot"
    $OpenBaseRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RegHiveType, $env:COMPUTERNAME)
    $suffixes | %{$suffix = $_
        $OpenRegSubKey = $OpenBaseRegKey.OpenSubKey($suffix)
        If ($OpenRegSubKey) {
            $GetRegKeyVal = Foreach($RegKeyValue in $OpenRegSubKey.GetValueNames()){$RegKeyValue}
            $GetRegKeyVal
        } else {
            Write-Output "error, could not open registry class for suffix $suffix"
        }
    }
}

Set_PerceivedTypeInRegistryForPreviewPane