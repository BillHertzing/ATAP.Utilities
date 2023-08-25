
[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()


$AnsibleTypeCodePreamble = @"
using System;
using System.IO;
using System.Collections.Generic;
using System.Reflection;
using YamlDotNet.Core;
using YamlDotNet.Core.Events;
using YamlDotNet.Serialization;
namespace ATAP.Utilities.Ansible {

"@
$AnsibleTypeCodePostscript = @"
}
"@

[void]$sb.Append($AnsibleTypeCodePreamble)

# load all the local .cs files into $sb
$AnsibleTypeFiles = Get-ChildItem -Path $PSScriptRoot -Filter *.cs -Recurse
foreach ($AnsibleTypeFile in $AnsibleTypeFiles) {
    [void]$sb.Append($(Get-Content $AnsibleTypeFile -Raw))
}

[void]$sb.Append($AnsibleTypeCodePostscript)

$outputFilePath = join-path ".." "AnsibleTypes.dll"
if (Test-Path $outputFilePath) { Remove-Item $outputFilePath -Force}

# add references to external assemblies. Ensure the assemblies referenced are compatable with the current default DotNet framework
# reference the YamlDotNet.dll assembly found in the current directory
$yamlDotNetAssemblyPath = join-path ".." "YamlDotNet.dll"

$referencedAssemblies = @(
    $yamlDotNetAssemblyPath
    'System.Collections.dll'
)

# Now you can use the YamlDotNet classes and functions in your PowerShell script
# Compile and generate the DLL using Add-Type cmdlet
Add-Type -TypeDefinition $sb.ToString() -ReferencedAssemblies $referencedAssemblies -OutputAssembly $outputFilePath

