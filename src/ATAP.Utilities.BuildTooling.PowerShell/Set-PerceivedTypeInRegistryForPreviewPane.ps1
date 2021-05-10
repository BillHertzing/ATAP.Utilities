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
  $suffixesString= @"
  "@
  $suffixes =
  ('config'.'.csproj', '.dot', '.go', '.html', '.json', '.lock', '.log', '.md', '.props', '.ps1', '.psd1', '.psm1', '.psproj', '.pubxml', '.rb', '.reg', '.saas', '.sccs', '.sln', '.targets', '.xml', '.yml')
    $RegHiveType = [Microsoft.Win32.RegistryHive]::"ClassesRoot"
    $OpenBaseRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RegHiveType, $env:COMPUTERNAME)
    $suffixes | %{$suffix = $_
        $OpenRegSubKey = $OpenBaseRegKey.OpenSubKey($suffix)
        If ($OpenRegSubKey) {
              # If 'PerceivedType' is NOT present in the list of all RegKeyVal (s), add a new Key named PerceivedType of type String with Data (value) of 'text
              # If 'PerceivedType' IS present in the list of all RegKeyVal (s), and -force is true, ensure it is of type String with Data (value) of 'text'
              # If 'PerceivedType' IS present in the list of all RegKeyVal (s), and -force is false, do nothing to the RegSubKey, accumulate it for output later
            $GetRegKeyVal = Foreach($RegKeyValue in $OpenRegSubKey.GetValueNames()){
              $GetRegKeyVal
            }
        } else {
            Write-Output "error, could not open registry class for suffix $suffix"
        }
    }
}

Set_PerceivedTypeInRegistryForPreviewPane
