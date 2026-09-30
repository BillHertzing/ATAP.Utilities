if (-not ('ATAP.Utilities.PowerShell.PackagedAppPrivateLauncher' -as [type])) {
  Add-Type @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace ATAP.Utilities.PowerShell
{
    // A suspended execution alias supplies the package token without starting the desktop or
    // making a network request. The desktop then starts suspended with a private environment;
    // the caller binds its proxy bridge to the new PID before allowing any desktop code to run.
    public static class PackagedAppPrivateLauncher
    {
        private const uint CreateSuspended = 0x00000004;
        private const uint CreateNoWindow = 0x08000000;
        private const uint CreateUnicodeEnvironment = 0x00000400;
        private const uint TokenDuplicate = 0x0002;
        private const uint TokenQuery = 0x0008;
        private const uint TokenAllAccess = 0x000F01FF;
        private const int ErrorInsufficientBuffer = 122;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct StartupInfo
        {
            public int Size;
            public string Reserved, Desktop, Title;
            public uint X, Y, XSize, YSize, XCountChars, YCountChars, FillAttribute, Flags;
            public short ShowWindow, Reserved2;
            public IntPtr Reserved2Pointer, StandardInput, StandardOutput, StandardError;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct ProcessInformation
        {
            public IntPtr Process, Thread;
            public int ProcessId, ThreadId;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CreateProcessW(string application, StringBuilder commandLine,
            IntPtr processAttributes, IntPtr threadAttributes, bool inheritHandles,
            uint creationFlags, IntPtr environment, string currentDirectory,
            ref StartupInfo startupInfo, out ProcessInformation information);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool DuplicateTokenEx(IntPtr existing, uint access, IntPtr attributes,
            int impersonationLevel, int tokenType, out IntPtr token);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CreateProcessWithTokenW(IntPtr token, uint logonFlags,
            string application, StringBuilder commandLine, uint creationFlags, IntPtr environment,
            string currentDirectory, ref StartupInfo startupInfo, out ProcessInformation information);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetPackageFamilyName(IntPtr process, ref int length,
            StringBuilder familyName);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern uint ResumeThread(IntPtr thread);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool TerminateProcess(IntPtr process, uint exitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);

        private static StartupInfo NewStartupInfo() => new StartupInfo
        {
            Size = Marshal.SizeOf<StartupInfo>()
        };

        private static string PackageFamily(IntPtr process)
        {
            int length = 0;
            int status = GetPackageFamilyName(process, ref length, null);
            if (status != ErrorInsufficientBuffer || length <= 1)
                throw new InvalidOperationException("The process has no readable package family.");
            var family = new StringBuilder(length);
            status = GetPackageFamilyName(process, ref length, family);
            if (status != 0)
                throw new Win32Exception(status, "The process package family could not be read.");
            return family.ToString();
        }

        private static byte[] BuildEnvironment(IDictionary<string, string> variables)
        {
            var sorted = new SortedDictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var entry in variables)
            {
                if (string.IsNullOrWhiteSpace(entry.Key) || entry.Key.IndexOfAny(new[] { '=', '\0' }) >= 0 ||
                    entry.Value == null || entry.Value.IndexOf('\0') >= 0)
                    throw new ArgumentException("The private environment contains an invalid entry.", nameof(variables));
                sorted.Add(entry.Key, entry.Value);
            }
            var entries = new List<string>();
            foreach (var entry in sorted) entries.Add(entry.Key + "=" + entry.Value);
            return Encoding.Unicode.GetBytes(string.Join("\0", entries) + "\0\0");
        }

        public static SuspendedPackagedProcess Prepare(string expectedAppUserModelId,
            string bootstrapAliasPath, string desktopExecutablePath, string arguments,
            string workingDirectory, IDictionary<string, string> environment)
        {
            if (string.IsNullOrWhiteSpace(expectedAppUserModelId) ||
                expectedAppUserModelId.IndexOf('!') <= 0)
                throw new ArgumentException("An AppUserModelId is required.", nameof(expectedAppUserModelId));
            if (string.IsNullOrWhiteSpace(bootstrapAliasPath) || !Path.IsPathFullyQualified(bootstrapAliasPath) ||
                !File.Exists(bootstrapAliasPath))
                throw new ArgumentException("The package bootstrap alias is unavailable.", nameof(bootstrapAliasPath));
            if (string.IsNullOrWhiteSpace(desktopExecutablePath) || !Path.IsPathFullyQualified(desktopExecutablePath) ||
                !File.Exists(desktopExecutablePath))
                throw new ArgumentException("The packaged desktop executable is unavailable.", nameof(desktopExecutablePath));
            if (string.IsNullOrWhiteSpace(workingDirectory) || !Directory.Exists(workingDirectory))
                throw new ArgumentException("The working directory is unavailable.", nameof(workingDirectory));
            if (environment == null) throw new ArgumentNullException(nameof(environment));

            string expectedFamily = expectedAppUserModelId.Substring(0, expectedAppUserModelId.IndexOf('!'));
            ProcessInformation bootstrap = default;
            ProcessInformation desktop = default;
            IntPtr bootstrapToken = IntPtr.Zero;
            IntPtr primaryToken = IntPtr.Zero;
            IntPtr environmentPointer = IntPtr.Zero;
            byte[] environmentBytes = null;
            try
            {
                var bootstrapStartup = NewStartupInfo();
                var bootstrapCommand = new StringBuilder("\"" + bootstrapAliasPath + "\"");
                if (!CreateProcessW(bootstrapAliasPath, bootstrapCommand, IntPtr.Zero, IntPtr.Zero,
                    false, CreateSuspended | CreateNoWindow, IntPtr.Zero, workingDirectory,
                    ref bootstrapStartup, out bootstrap))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Package bootstrap creation failed.");
                if (!string.Equals(PackageFamily(bootstrap.Process), expectedFamily, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("The bootstrap alias belongs to a different package.");
                if (!OpenProcessToken(bootstrap.Process, TokenDuplicate | TokenQuery, out bootstrapToken))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Package bootstrap token could not be opened.");
                if (!DuplicateTokenEx(bootstrapToken, TokenAllAccess, IntPtr.Zero, 2, 1, out primaryToken))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Package bootstrap token could not be duplicated.");

                environmentBytes = BuildEnvironment(environment);
                environmentPointer = Marshal.AllocHGlobal(environmentBytes.Length);
                Marshal.Copy(environmentBytes, 0, environmentPointer, environmentBytes.Length);
                var desktopStartup = NewStartupInfo();
                var desktopCommand = new StringBuilder("\"" + desktopExecutablePath + "\"" +
                    (string.IsNullOrWhiteSpace(arguments) ? "" : " " + arguments));
                if (!CreateProcessWithTokenW(primaryToken, 0, desktopExecutablePath, desktopCommand,
                    CreateSuspended | CreateUnicodeEnvironment, environmentPointer, workingDirectory,
                    ref desktopStartup, out desktop))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Private packaged desktop creation failed.");
                if (!string.Equals(PackageFamily(desktop.Process), expectedFamily, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("The desktop process belongs to a different package.");

                var result = new SuspendedPackagedProcess(desktop.Process, desktop.Thread, desktop.ProcessId);
                desktop = default; // result now owns both handles
                return result;
            }
            finally
            {
                if (desktop.Process != IntPtr.Zero)
                {
                    TerminateProcess(desktop.Process, 0);
                    CloseHandle(desktop.Thread);
                    CloseHandle(desktop.Process);
                }
                if (bootstrap.Process != IntPtr.Zero)
                {
                    TerminateProcess(bootstrap.Process, 0); // alias code never executes
                    CloseHandle(bootstrap.Thread);
                    CloseHandle(bootstrap.Process);
                }
                if (primaryToken != IntPtr.Zero) CloseHandle(primaryToken);
                if (bootstrapToken != IntPtr.Zero) CloseHandle(bootstrapToken);
                if (environmentPointer != IntPtr.Zero)
                {
                    var zeroes = new byte[environmentBytes.Length];
                    Marshal.Copy(zeroes, 0, environmentPointer, zeroes.Length);
                    Marshal.FreeHGlobal(environmentPointer);
                }
                if (environmentBytes != null) Array.Clear(environmentBytes, 0, environmentBytes.Length);
            }
        }

        public sealed class SuspendedPackagedProcess : IDisposable
        {
            private IntPtr process;
            private IntPtr thread;
            private bool resumed;
            public int ProcessId { get; }

            internal SuspendedPackagedProcess(IntPtr process, IntPtr thread, int processId)
            {
                this.process = process;
                this.thread = thread;
                ProcessId = processId;
            }

            public Process Resume()
            {
                if (process == IntPtr.Zero || resumed)
                    throw new InvalidOperationException("The packaged desktop process is no longer suspended.");
                var tracked = Process.GetProcessById(ProcessId);
                if (ResumeThread(thread) == uint.MaxValue)
                {
                    tracked.Dispose();
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "The packaged desktop could not resume.");
                }
                resumed = true;
                return tracked;
            }

            public void Dispose()
            {
                if (process == IntPtr.Zero) return;
                if (!resumed) TerminateProcess(process, 0);
                CloseHandle(thread);
                CloseHandle(process);
                thread = IntPtr.Zero;
                process = IntPtr.Zero;
            }
        }
    }
}
'@
}
