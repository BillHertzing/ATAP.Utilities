using System;
using System.Runtime.InteropServices;
using ATAP.Utilities.ComputerInventory.Enumerations;

namespace ATAP.Utilities.ComputerInventory.Models
{
 
    public interface IRuntimeKind {
        bool IsConsoleApplication { get; }
        bool IsFreeBSD { get; }
        bool IsLinux { get; }
        bool IsOSX { get; }
        bool IsWindows { get; }
        RuntimePlatformLifetime Kind { get; }
    }

    public class RuntimeKind : IRuntimeKind {
        const string UnknownRunTimeInformationOSPlatformExceptionMessage = "unknown RuntimeInformation OSPlatform : {0}";
        public RuntimeKind(bool isCA) {
            IsConsoleApplication=isCA;
            RuntimePlatformLifetime kind;
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) {
                kind=isCA ? RuntimePlatformLifetime.WindowsConsoleApp : RuntimePlatformLifetime.WindowsService;
                IsWindows=true;
            } else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux)) {
                kind=isCA ? RuntimePlatformLifetime.LinuxConsoleApp : RuntimePlatformLifetime.LinuxDaemon;
                IsLinux=true;
                //  } else if (RuntimeInformation.IsOSPlatform(OSPlatform.FreeBSD)) {
                //     kind=isCA ? RuntimePlatformLifetime.FreeBSDConsoleApp : RuntimePlatformLifetime.FreeBSDDaemon;
                //     IsFreeBSD=true;
            } else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX)) {
                kind=isCA ? RuntimePlatformLifetime.OSXConsoleApp : RuntimePlatformLifetime.OSXDaemon;
                IsOSX=true;
            } else {
                throw new InvalidOperationException(String.Format(UnknownRunTimeInformationOSPlatformExceptionMessage, RuntimeInformation.FrameworkDescription));
            }
        }
        public RuntimePlatformLifetime Kind { get; private set; }
        public bool IsConsoleApplication { get; private set; } = false;
        public bool IsWindows { get; private set; } = false;
        public bool IsLinux { get; private set; } = false;
        public bool IsOSX { get; private set; } = false;
        public bool IsFreeBSD { get; private set; } = false;
    }
   
}
