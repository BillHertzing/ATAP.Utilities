#
# Set_PerceivedTypeInRegistryForPreviewPane.ps1
#   One liner to get extensions  $list = (gci -re | ?{! $_.PSisContainer} |%{($_.extension).Trim('.')}) | sort -unique ;$list -join ','
#
[CmdletBinding(SupportsShouldProcess=$true)]
param (

)

write-verbose "psModulePath = $($env:psmodulepath.Split(';') -join [environment]::NewLine)"


Set_PerceivedTypeInRegistryForPreviewPane -WhatIf:$WhatIfPreference -Verbose:$VerbosePreference
