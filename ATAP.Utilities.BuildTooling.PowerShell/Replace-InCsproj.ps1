[CmdletBinding(SupportsShouldProcess=$true)]
param (
     [string]$include = "\.csproj$",
    [string]$path = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\",
    [string]$exclude = "\.bin$|\.obj$"
)
Function Replace-InCsproj {
[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string]$include = "*.csproj",
    [string]$path = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\",
    [string]$exclude = "*.bin,*.obj,*Backup*,*OpenHardwareMonitorLib*"
    [string]$excludeRegEx = "(?:\.bin|\.obj|Backup|OpenHardwareMonitorLib)"
)

$replacehash = {
}

$files = gci $path -recurse -include $include -exclude $exclude | ?{$_.fullname -notmatch $excludeRegex}
foreach ($fn in $files) {}
 # replace each
    $text = [IO.File]::ReadAllText($fn) -replace $strToMatch, $replacement
    [IO.File]::WriteAllText($fn, $text)
}
Replace-InCsproj
