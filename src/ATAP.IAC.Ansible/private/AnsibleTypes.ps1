$AnsibleTypeCode = @"
using System;

namespace ATAP.Utilities.ATAP.IAC.Ansible
{
    public class CopyFile
    {
        public string Source { get; set; }
        public string Target { get; set; }
        public string Permissions { get; set; }
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
Add-Type -TypeDefinition $AnsibleTypeCode -OutputAssembly "ATAP.Utilities.ATAP.IAC.Ansible.dll"
