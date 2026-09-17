function Join-DabMcpProcessLifetime {
  <#
  .SYNOPSIS
    Binds every child of the current process to the current process's lifetime and clears a
    leftover DAB listener on the entry's loopback port before a new one starts.
  .DESCRIPTION
    An MCP harness runs pwsh -File Mcp/Start-DabMcpServer.ps1, which runs dab.exe. When the harness
    terminates its child pwsh, the grandchild dab.exe (with its Kestrel listener) survives, and
    every desktop restart or reconnect leaves ten more of them behind (Task 15.196.l item 5;
    "runaway microsoft.dataapi.builder" on utat01, 2026-09-16).

    Two controls, both quiet on stdout because the caller owns an MCP stdio channel:
    - A Windows job object with JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE is created and the current
      process is assigned to it. Children inherit the job; when this process ends for any reason
      (TerminateProcess included) the handle closes and the job kills them. Nested jobs are
      supported since Windows 8, so a harness that already jobs this process does not break it.
    - Any process already listening on -McpHostUrl's port is a leftover from a crashed or
      orphaned launch of this same entry (ports are unique per catalog entry). It is stopped only
      when its image is dab.exe, never anything else.

    Failure to establish either control is reported through the PSFramework log and does not
    prevent the launch; the controls are best-effort hardening, not a startup gate.
  .PARAMETER McpHostUrl
    The entry's loopback Kestrel URL (http://127.0.0.1:<port>); only the port is used.
  .OUTPUTS
    PSCustomObject with JobAssigned and LeftoverStopped members.
  .EXAMPLE
    Join-DabMcpProcessLifetime -McpHostUrl 'http://127.0.0.1:5142'
  .NOTES
    Function-only file; no top-level executable code.
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^http://(127\.0\.0\.1|localhost):[0-9]+$')]
    [string] $McpHostUrl
  )

  begin {
    $fn = 'Join-DabMcpProcessLifetime'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
  }

  process {
    $jobAssigned = $false
    $leftoverStopped = @()

    if (-not ('ATAP.Utilities.DabMcp.JobObject' -as [type])) {
      try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace ATAP.Utilities.DabMcp
{
    public static class JobObject
    {
        [StructLayout(LayoutKind.Sequential)]
        struct JOBOBJECT_BASIC_LIMIT_INFORMATION
        {
            public long PerProcessUserTimeLimit; public long PerJobUserTimeLimit; public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize; public UIntPtr MaximumWorkingSetSize; public uint ActiveProcessLimit;
            public UIntPtr Affinity; public uint PriorityClass; public uint SchedulingClass;
        }
        [StructLayout(LayoutKind.Sequential)]
        struct IO_COUNTERS
        {
            public ulong ReadOperationCount; public ulong WriteOperationCount; public ulong OtherOperationCount;
            public ulong ReadTransferCount; public ulong WriteTransferCount; public ulong OtherTransferCount;
        }
        [StructLayout(LayoutKind.Sequential)]
        struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
        {
            public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation; public IO_COUNTERS IoInfo;
            public UIntPtr ProcessMemoryLimit; public UIntPtr JobMemoryLimit; public UIntPtr PeakProcessMemoryUsed; public UIntPtr PeakJobMemoryUsed;
        }
        const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000;
        const int JobObjectExtendedLimitInformation = 9;
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr CreateJobObject(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError = true)] static extern bool SetInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint length);
        [DllImport("kernel32.dll", SetLastError = true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
        [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr GetCurrentProcess();
        static IntPtr handle = IntPtr.Zero; // held for the process lifetime on purpose: closing it is what kills the job

        public static bool BindCurrentProcess()
        {
            if (handle != IntPtr.Zero) { return true; }
            var job = CreateJobObject(IntPtr.Zero, null);
            if (job == IntPtr.Zero) { throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()); }
            var info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
            info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            var size = Marshal.SizeOf(info);
            var buffer = Marshal.AllocHGlobal(size);
            try
            {
                Marshal.StructureToPtr(info, buffer, false);
                if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, buffer, (uint)size)) { throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()); }
            }
            finally { Marshal.FreeHGlobal(buffer); }
            if (!AssignProcessToJobObject(job, GetCurrentProcess())) { throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()); }
            handle = job;
            return true;
        }
    }
}
'@ -ErrorAction Stop
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Job-object type unavailable; dab.exe lifetime is not bound to this launcher. $($_.Exception.Message)"
      }
    }
    if ('ATAP.Utilities.DabMcp.JobObject' -as [type]) {
      try {
        $jobAssigned = [ATAP.Utilities.DabMcp.JobObject]::BindCurrentProcess()
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Could not bind this launcher to a kill-on-close job object. $($_.Exception.Message)"
      }
    }

    $port = [int]([uri]$McpHostUrl).Port
    try {
      $owners = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique)
      foreach ($ownerId in $owners) {
        if ($ownerId -eq $PID) { continue }
        $owner = Get-Process -Id $ownerId -ErrorAction SilentlyContinue
        if ($null -eq $owner -or $owner.ProcessName -ne 'dab') { continue }
        # Verbose only: this process owns an MCP stdio channel and Important/host output would
        # land in front of the JSON-RPC handshake.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Stopping leftover dab.exe $ownerId that still owns port $port before relaunch."
        Stop-Process -Id $ownerId -Force -ErrorAction Stop
        $leftoverStopped += $ownerId
      }
      if ($leftoverStopped.Count -gt 0) {
        # The listener is released asynchronously after the kill; a relaunch that races it fails
        # with "address in use". Wait, bounded, until nothing listens on the port.
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        while ([DateTime]::UtcNow -lt $deadline -and @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue).Count -gt 0) {
          Start-Sleep -Milliseconds 250
        }
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Leftover-listener check on port $port did not complete. $($_.Exception.Message)"
    }

    [pscustomobject]@{ JobAssigned = $jobAssigned; LeftoverStopped = $leftoverStopped }
  }
}
