if (-not ('ATAP.Utilities.PowerShell.PackagedAppActivator' -as [type])) {
  Add-Type @'
using System;
using System.Runtime.InteropServices;

namespace ATAP.Utilities.PowerShell
{
    // Launches an MSIX/packaged desktop app (Claude desktop, Codex desktop) through the shell's
    // ApplicationActivationManager, the supported path for packaged apps. CreateProcess on the
    // WindowsApps executable is denied to a non-elevated token, which is why the metered desktop
    // launchers failed on utat01 (UAC on) while working on utat022 (UAC off). Activation returns the
    // process id so the desktop proxy bridge can bind authorization to exactly that process.
    public static class PackagedAppActivator
    {
        [ComImport, Guid("2e941141-7f97-4756-ba1d-9decde894a3d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IApplicationActivationManager
        {
            int ActivateApplication([In] string appUserModelId, [In] string arguments, [In] ActivateOptions options, [Out] out uint processId);
            int ActivateForFile([In] string appUserModelId, [In] IntPtr itemArray, [In] string verb, [Out] out uint processId);
            int ActivateForProtocol([In] string appUserModelId, [In] IntPtr itemArray, [Out] out uint processId);
        }

        [ComImport, Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")]
        private class ApplicationActivationManager { }

        [Flags]
        private enum ActivateOptions
        {
            None = 0x00000000,
            DesignMode = 0x00000001,
            NoErrorUI = 0x00000002,
            NoSplashScreen = 0x00000004
        }

        public static int Activate(string appUserModelId, string arguments)
        {
            if (string.IsNullOrWhiteSpace(appUserModelId)) { throw new ArgumentException("An AppUserModelId is required.", nameof(appUserModelId)); }
            var manager = (IApplicationActivationManager)new ApplicationActivationManager();
            uint processId;
            var hresult = manager.ActivateApplication(appUserModelId, arguments ?? string.Empty, ActivateOptions.NoErrorUI, out processId);
            if (hresult != 0) { Marshal.ThrowExceptionForHR(hresult); }
            if (processId == 0) { throw new InvalidOperationException("Packaged app activation returned no process id for '" + appUserModelId + "'."); }
            return checked((int)processId);
        }
    }
}
'@
}
