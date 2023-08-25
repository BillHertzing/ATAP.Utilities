
# ToDo: Make this opinionated based on something in the parent tree
$assemblyFileName = "ATAP.IAC.Ansible.dll"
$outputFilePath = join-path ".." $assemblyFileName

[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

$AnsibleTypeCodePreamble = @"
using System.Collections.Generic;
namespace ATAP.IAC.Ansible {

"@
$AnsibleTypeCodePostscript = @"
}
"@

# add the preamble to the StringBuilder
[void]$sb.Append($AnsibleTypeCodePreamble)

# load all the local .cs files into $sb
$AnsibleTypeFiles = Get-ChildItem -Path $PSScriptRoot -Filter *.cs -Recurse
foreach ($AnsibleTypeFile in $AnsibleTypeFiles) {
    [void]$sb.Append($(Get-Content $AnsibleTypeFile -Raw))
}

# add the postscript
[void]$sb.Append($AnsibleTypeCodePostscript)

# add references to external assemblies. Ensure the assemblies referenced are compatable with the current default DotNet framework
$referencedAssemblies = @(
    'System.Collections.dll'
)

# ToDo make this controllable via an argument
if ($true) {
  set-content -path './SourceForDebugging.txt' -Value $sb.ToString()
}

# Compile and generate the DLL using Add-Type cmdlet
# Note that if this step generates an error, the .dll may have been locked by previous runs, if so, kill the process having the lock andretry
if (Test-Path $outputFilePath) { Remove-Item $outputFilePath -Force }
Add-Type -TypeDefinition $sb.ToString() -ReferencedAssemblies $referencedAssemblies -OutputAssembly $outputFilePath
