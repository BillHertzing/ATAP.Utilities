if (-not ('ATAP.Utilities.PowerShell.PackagedAppReactivationGuard' -as [type])) {
  Add-Type @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.PowerShell
{
    // A packaged app whose manifest declares no appExecutionAlias cannot be started through
    // PackagedAppPrivateLauncher, because that path harvests its package token from a suspended
    // alias of the same package. Claude is such a package. Its metered instance is therefore an
    // ordinary activation, and any later activation - a Start-menu click, a taskbar pin, a
    // self-restart after update - creates a second process tree that the desktop proxy bridge
    // has no reason to trust. The bridge rejects it, which the desktop reports to the user as a
    // network failure, and the user sees a Claude window that cannot reach the API.
    //
    // This guard registers the AppUserModelId around a known metered root for the bridge's
    // lifetime. A process of the same package family that is neither the metered root nor one of
    // its descendants is an orphan: it is terminated, and the metered window is brought forward,
    // so the activation the user asked for is served by the instance that is actually metered.
    //
    // The guard never terminates the metered tree, and stops acting the moment the metered root
    // exits, so it cannot outlive the thing it was protecting and start killing a later launch.
    public sealed class PackagedAppReactivationGuard : IDisposable
    {
        private const uint Th32csSnapProcess = 0x00000002;
        private const uint ProcessQueryLimitedInformation = 0x1000;
        private const int ErrorInsufficientBuffer = 122;

        private readonly string packageFamilyName;
        private readonly string desktopExecutablePath;
        private readonly int meteredRootProcessId;
        private readonly TimeSpan pollInterval;
        private readonly CancellationTokenSource cancellation = new CancellationTokenSource();
        private Task guardLoop;
        private int terminatedProcessCount;
        private int disposed;

        public PackagedAppReactivationGuard(string appUserModelId, string desktopExecutablePath,
            int meteredRootProcessId)
            : this(appUserModelId, desktopExecutablePath, meteredRootProcessId, TimeSpan.FromSeconds(2))
        {
        }

        public PackagedAppReactivationGuard(string appUserModelId, string desktopExecutablePath,
            int meteredRootProcessId, TimeSpan pollInterval)
        {
            if (string.IsNullOrWhiteSpace(appUserModelId) || appUserModelId.IndexOf('!') <= 0)
            {
                throw new ArgumentException("An AppUserModelId is required.", nameof(appUserModelId));
            }

            if (string.IsNullOrWhiteSpace(desktopExecutablePath))
            {
                throw new ArgumentException("The desktop executable path is required.",
                    nameof(desktopExecutablePath));
            }

            if (meteredRootProcessId <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(meteredRootProcessId));
            }

            if (pollInterval <= TimeSpan.Zero || pollInterval > TimeSpan.FromMinutes(1))
            {
                throw new ArgumentOutOfRangeException(nameof(pollInterval));
            }

            using (Process root = Process.GetProcessById(meteredRootProcessId))
            {
                if (root.HasExited)
                {
                    throw new InvalidOperationException("The metered root process already exited.");
                }
            }

            packageFamilyName = appUserModelId.Substring(0, appUserModelId.IndexOf('!'));
            this.desktopExecutablePath = desktopExecutablePath;
            this.meteredRootProcessId = meteredRootProcessId;
            this.pollInterval = pollInterval;
        }

        public string PackageFamilyName => packageFamilyName;

        public string DesktopExecutablePath => desktopExecutablePath;

        public int MeteredRootProcessId => meteredRootProcessId;

        public int TerminatedProcessCount => Volatile.Read(ref terminatedProcessCount);

        public void Start()
        {
            ThrowIfDisposed();
            if (guardLoop != null)
            {
                throw new InvalidOperationException("The re-activation guard has already started.");
            }

            guardLoop = GuardLoopAsync(cancellation.Token);
        }

        private async Task GuardLoopAsync(CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    await Task.Delay(pollInterval, token).ConfigureAwait(false);
                }
                catch (OperationCanceledException)
                {
                    return;
                }

                try
                {
                    // The metered root is the whole justification for terminating anything. Once
                    // it is gone the guard has no tree to protect and must stop immediately.
                    if (!IsProcessAlive(meteredRootProcessId))
                    {
                        return;
                    }

                    SweepOnce();
                }
                catch
                {
                    // A single failed sweep - a process exiting underneath the enumeration, an
                    // access-denied handle - must not tear the guard down. The next poll retries.
                }
            }
        }

        // Public rather than private so the unit tests can drive one deterministic sweep instead
        // of racing the poll timer. PowerShell binds public members only, so an internal method
        // would be unreachable from Pester and the sweep would go untested.
        public void SweepOnce()
        {
            Dictionary<int, int> parents = SnapshotProcessParents();
            Process[] candidates = Process.GetProcesses();
            bool terminatedAny = false;
            try
            {
                foreach (Process candidate in candidates)
                {
                    int candidateId;
                    try
                    {
                        candidateId = candidate.Id;
                    }
                    catch
                    {
                        continue;
                    }

                    if (candidateId <= 0 || candidateId == meteredRootProcessId)
                    {
                        continue;
                    }

                    if (IsDescendantOf(candidateId, meteredRootProcessId, parents))
                    {
                        continue;
                    }

                    if (!IsSameDesktopApp(candidate, candidateId))
                    {
                        continue;
                    }

                    try
                    {
                        candidate.Kill(true);
                        Interlocked.Increment(ref terminatedProcessCount);
                        terminatedAny = true;
                    }
                    catch
                    {
                        // Already gone, or not killable from this token. Either way the next
                        // sweep re-evaluates it.
                    }
                }
            }
            finally
            {
                foreach (Process candidate in candidates)
                {
                    candidate.Dispose();
                }
            }

            // Only surface the metered window when an orphan was actually removed, so the guard
            // never steals focus during ordinary operation.
            if (terminatedAny)
            {
                ForegroundMeteredWindow();
            }
        }

        // Identity is tested two ways, because neither alone is sufficient.
        //
        // Package family catches an ordinary Windows activation of the package, which is the
        // common re-activation case. It is not sufficient on its own: a relaunch that starts the
        // same executable directly rather than through activation has no package identity at all
        // and reports as unpackaged, so a family-only test would silently ignore it.
        //
        // The full executable path catches that unpackaged relaunch. It must be the full path and
        // never the process name: the Claude Desktop package and the Claude Code CLI are both
        // named claude.exe, and a name test would make this guard terminate the user's CLI
        // sessions. Only the desktop's own WindowsApps path is ever a candidate here.
        private bool IsSameDesktopApp(Process candidate, int candidateId)
        {
            if (string.Equals(ReadPackageFamilyName(candidateId), packageFamilyName,
                    StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            try
            {
                string path = candidate.MainModule == null ? null : candidate.MainModule.FileName;
                return !string.IsNullOrEmpty(path) &&
                    string.Equals(path, desktopExecutablePath, StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                // A process this token cannot open is not one it could terminate either.
                return false;
            }
        }

        private void ForegroundMeteredWindow()
        {
            try
            {
                using (Process root = Process.GetProcessById(meteredRootProcessId))
                {
                    root.Refresh();
                    IntPtr window = root.MainWindowHandle;
                    if (window == IntPtr.Zero)
                    {
                        return;
                    }

                    if (IsIconic(window))
                    {
                        ShowWindow(window, 9); // SW_RESTORE
                    }

                    SetForegroundWindow(window);
                }
            }
            catch
            {
                // Focus is a courtesy, never a correctness requirement.
            }
        }

        private static bool IsProcessAlive(int processId)
        {
            try
            {
                using (Process process = Process.GetProcessById(processId))
                {
                    return !process.HasExited;
                }
            }
            catch
            {
                return false;
            }
        }

        private static bool IsDescendantOf(int processId, int rootProcessId,
            Dictionary<int, int> parents)
        {
            HashSet<int> seen = new HashSet<int>();
            int current = processId;
            for (int depth = 0; depth < 64 && current > 0 && seen.Add(current); depth++)
            {
                if (current == rootProcessId)
                {
                    return true;
                }

                if (!parents.TryGetValue(current, out current))
                {
                    return false;
                }
            }

            return false;
        }

        private static string ReadPackageFamilyName(int processId)
        {
            IntPtr handle = OpenProcess(ProcessQueryLimitedInformation, false, processId);
            if (handle == IntPtr.Zero)
            {
                return null;
            }

            try
            {
                int length = 0;
                int status = GetPackageFamilyName(handle, ref length, null);
                if (status != ErrorInsufficientBuffer || length <= 1)
                {
                    return null;
                }

                StringBuilder family = new StringBuilder(length);
                status = GetPackageFamilyName(handle, ref length, family);
                return status == 0 ? family.ToString() : null;
            }
            catch
            {
                return null;
            }
            finally
            {
                CloseHandle(handle);
            }
        }

        private static Dictionary<int, int> SnapshotProcessParents()
        {
            Dictionary<int, int> parents = new Dictionary<int, int>();
            IntPtr snapshot = CreateToolhelp32Snapshot(Th32csSnapProcess, 0);
            if (snapshot == new IntPtr(-1))
            {
                return parents;
            }

            try
            {
                ProcessEntry32 entry = new ProcessEntry32();
                entry.Size = (uint)Marshal.SizeOf<ProcessEntry32>();
                if (!Process32First(snapshot, ref entry))
                {
                    return parents;
                }

                do
                {
                    parents[unchecked((int)entry.ProcessId)] = unchecked((int)entry.ParentProcessId);
                    entry.Size = (uint)Marshal.SizeOf<ProcessEntry32>();
                }
                while (Process32Next(snapshot, ref entry));

                return parents;
            }
            finally
            {
                CloseHandle(snapshot);
            }
        }

        private void ThrowIfDisposed()
        {
            if (Volatile.Read(ref disposed) != 0)
            {
                throw new ObjectDisposedException(nameof(PackagedAppReactivationGuard));
            }
        }

        public void Dispose()
        {
            if (Interlocked.Exchange(ref disposed, 1) != 0)
            {
                return;
            }

            try
            {
                cancellation.Cancel();
                if (guardLoop != null)
                {
                    guardLoop.Wait(TimeSpan.FromSeconds(5));
                }
            }
            catch
            {
            }
            finally
            {
                cancellation.Dispose();
            }
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct ProcessEntry32
        {
            public uint Size;
            public uint Usage;
            public uint ProcessId;
            public IntPtr DefaultHeapId;
            public uint ModuleId;
            public uint Threads;
            public uint ParentProcessId;
            public int PriorityClassBase;
            public uint Flags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
            public string ExeFile;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint processId);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool Process32First(IntPtr snapshot, ref ProcessEntry32 entry);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool Process32Next(IntPtr snapshot, ref ProcessEntry32 entry);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr OpenProcess(uint access, bool inheritHandle, int processId);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetPackageFamilyName(IntPtr process, ref int length,
            StringBuilder familyName);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);

        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr window);

        [DllImport("user32.dll")]
        private static extern bool IsIconic(IntPtr window);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr window, int command);
    }
}
'@
}
