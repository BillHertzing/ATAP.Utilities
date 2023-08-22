$BuildToolingPowershellTypeCode = @"
using System;

namespace ATAP.Utilities.BuildTooling.Powershell
{
    public class ModuleInfo
    {
        public string Name { get; set; }
        public string Vewrsion { get; set; }
    }
    public class ChocolateyPackage
    {
        public string Name { get; set; }
        public string Version { get; set; }
        public bool PreRelease { get; set; }
        public string[] AddedParameters { get; set; }
    }
}
"@

# Compile and generate the DLL using Add-Type cmdlet
Add-Type -TypeDefinition $BuildToolingPowershellTypeCode -OutputAssembly "../ATAP.Utilities.BuildTooling.Powershell.dll"
