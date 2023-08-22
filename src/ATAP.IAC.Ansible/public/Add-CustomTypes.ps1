
# add references to external assemblies. Ensure the assemblies referenced are compatable with the current default DotNet framework
# reference the YamlDotNet.dll assembly found in the parent directory. Paent should be the module's main packge direcotry, a peer of the .psm1 and .psd1 files.
# This allows access to the YamlDotNet library functions without the need to install it via the Powershell Gallery.
# NOTE: the YamlDotNet.dll assembly must be compatable with the current default.Net framework version installed on the system
$assemblyFileName = "AnsibleTypes.dll"

if ($env:Environment -eq 'Development') {
# when the script is run from a development environment, use the below line to reference the DLL in the parent directory
$ModuleCustomTypesAssemblyPath = join-path (get-item $PSScriptRoot).parent.FullName $assemblyFileName
} else {
# when the script is run from a production or QualityAssurance environment, use the below line to reference the DLL in the module's main package directory
$ModuleCustomTypesAssemblyPath = join-path $PSScriptRoot $assemblyFileName
}
# Load the custom DLL
Add-Type -Path $ModuleCustomTypesAssemblyPath
