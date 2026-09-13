if (-not ('ATAP.Utilities.PowerShell.AceOutpostDesktopProxyBridge' -as [type])) {
  Add-Type @'
using System;
using System.Buffers;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.PowerShell
{
    public sealed class AceOutpostDesktopProxyBridge : IDisposable
    {
        private const int AddressFamilyInterNetwork = 2;
        private const int TcpTableOwnerPidAll = 5;
        private const uint Th32csSnapProcess = 0x00000002;
        private const int MaximumHeaderBytes = 65536;

        private readonly int upstreamPort;
        private readonly byte[] authorizationHeader;
        private readonly TcpListener listener;
        private readonly CancellationTokenSource cancellation = new CancellationTokenSource();
        private readonly ManualResetEventSlim rootReady = new ManualResetEventSlim(false);
        private readonly ConcurrentDictionary<int, Task> connections = new ConcurrentDictionary<int, Task>();
        private Task acceptLoop;
        private int allowedRootProcessId;
        private int nextConnectionId;
        private int acceptedConnectionCount;
        private int rejectedConnectionCount;
        private int disposed;

        public AceOutpostDesktopProxyBridge(int upstreamPort, string credential)
        {
            if (upstreamPort < 1 || upstreamPort > 65535)
            {
                throw new ArgumentOutOfRangeException(nameof(upstreamPort));
            }

            if (string.IsNullOrEmpty(credential) || credential.IndexOf(':') <= 0 ||
                credential.EndsWith(":", StringComparison.Ordinal) ||
                credential.IndexOf('\r') >= 0 || credential.IndexOf('\n') >= 0)
            {
                throw new ArgumentException("The bridge credential is invalid.", nameof(credential));
            }

            this.upstreamPort = upstreamPort;
            byte[] credentialBytes = Encoding.UTF8.GetBytes(credential);
            try
            {
                string encoded = Convert.ToBase64String(credentialBytes);
                authorizationHeader = Encoding.ASCII.GetBytes("Proxy-Authorization: Basic " + encoded + "\r\n");
            }
            finally
            {
                CryptographicOperations.ZeroMemory(credentialBytes);
            }

            listener = new TcpListener(IPAddress.Loopback, 0);
        }

        public int LocalPort
        {
            get
            {
                ThrowIfDisposed();
                IPEndPoint endpoint = listener.LocalEndpoint as IPEndPoint;
                return endpoint == null ? 0 : endpoint.Port;
            }
        }

        public int AcceptedConnectionCount => Volatile.Read(ref acceptedConnectionCount);

        public int RejectedConnectionCount => Volatile.Read(ref rejectedConnectionCount);

        public void Start()
        {
            ThrowIfDisposed();
            if (acceptLoop != null)
            {
                throw new InvalidOperationException("The desktop proxy bridge has already started.");
            }

            listener.Start(128);
            acceptLoop = AcceptLoopAsync(cancellation.Token);
        }

        public void SetAllowedRootProcess(int processId)
        {
            ThrowIfDisposed();
            if (processId <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(processId));
            }

            if (Interlocked.CompareExchange(ref allowedRootProcessId, processId, 0) != 0)
            {
                throw new InvalidOperationException("The allowed desktop root process is already set.");
            }

            using (Process process = Process.GetProcessById(processId))
            {
                if (process.HasExited)
                {
                    throw new InvalidOperationException("The allowed desktop root process already exited.");
                }
            }

            rootReady.Set();
        }

        private async Task AcceptLoopAsync(CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                TcpClient client = null;
                try
                {
                    client = await listener.AcceptTcpClientAsync(token).ConfigureAwait(false);
                    int connectionId = Interlocked.Increment(ref nextConnectionId);
                    Task task = HandleConnectionAsync(client, token);
                    connections[connectionId] = task;
                    _ = task.ContinueWith(
                        _ => connections.TryRemove(connectionId, out Task ignored),
                        CancellationToken.None,
                        TaskContinuationOptions.ExecuteSynchronously,
                        TaskScheduler.Default);
                }
                catch (OperationCanceledException) when (token.IsCancellationRequested)
                {
                    client?.Dispose();
                    break;
                }
                catch (ObjectDisposedException) when (token.IsCancellationRequested)
                {
                    client?.Dispose();
                    break;
                }
                catch
                {
                    client?.Dispose();
                    if (!token.IsCancellationRequested)
                    {
                        Interlocked.Increment(ref rejectedConnectionCount);
                    }
                }
            }
        }

        private async Task HandleConnectionAsync(TcpClient client, CancellationToken bridgeToken)
        {
            using (client)
            {
                try
                {
                    if (!rootReady.Wait(TimeSpan.FromSeconds(5), bridgeToken))
                    {
                        Interlocked.Increment(ref rejectedConnectionCount);
                        return;
                    }

                    IPEndPoint clientEndpoint = client.Client.RemoteEndPoint as IPEndPoint;
                    IPEndPoint bridgeEndpoint = client.Client.LocalEndPoint as IPEndPoint;
                    if (clientEndpoint == null || bridgeEndpoint == null ||
                        !IPAddress.IsLoopback(clientEndpoint.Address) ||
                        !IPAddress.IsLoopback(bridgeEndpoint.Address))
                    {
                        Interlocked.Increment(ref rejectedConnectionCount);
                        return;
                    }

                    int ownerProcessId = FindTcpOwnerProcessId(clientEndpoint.Port, bridgeEndpoint.Port);
                    if (ownerProcessId <= 0 || !IsProcessOrDescendant(ownerProcessId, Volatile.Read(ref allowedRootProcessId)))
                    {
                        Interlocked.Increment(ref rejectedConnectionCount);
                        return;
                    }

                    NetworkStream clientStream = client.GetStream();
                    using (CancellationTokenSource headerTimeout = CancellationTokenSource.CreateLinkedTokenSource(bridgeToken))
                    {
                        headerTimeout.CancelAfter(TimeSpan.FromSeconds(10));
                        byte[] header = await ReadHeaderAsync(clientStream, headerTimeout.Token).ConfigureAwait(false);
                        if (ContainsProxyAuthorization(header))
                        {
                            Interlocked.Increment(ref rejectedConnectionCount);
                            return;
                        }

                        using (TcpClient upstream = new TcpClient(AddressFamily.InterNetwork))
                        {
                            await upstream.ConnectAsync(IPAddress.Loopback, upstreamPort, headerTimeout.Token).ConfigureAwait(false);
                            NetworkStream upstreamStream = upstream.GetStream();
                            byte[] authenticatedHeader = InjectAuthorization(header);
                            try
                            {
                                await upstreamStream.WriteAsync(authenticatedHeader.AsMemory(), headerTimeout.Token).ConfigureAwait(false);
                            }
                            finally
                            {
                                CryptographicOperations.ZeroMemory(authenticatedHeader);
                            }

                            Interlocked.Increment(ref acceptedConnectionCount);
                            using (CancellationTokenSource relayCancellation = CancellationTokenSource.CreateLinkedTokenSource(bridgeToken))
                            {
                                Task clientToUpstream = clientStream.CopyToAsync(upstreamStream, relayCancellation.Token);
                                Task upstreamToClient = upstreamStream.CopyToAsync(clientStream, relayCancellation.Token);
                                await Task.WhenAny(clientToUpstream, upstreamToClient).ConfigureAwait(false);
                                relayCancellation.Cancel();
                                try
                                {
                                    await Task.WhenAll(clientToUpstream, upstreamToClient).ConfigureAwait(false);
                                }
                                catch (OperationCanceledException) when (relayCancellation.IsCancellationRequested)
                                {
                                }
                                catch (IOException)
                                {
                                }
                                catch (SocketException)
                                {
                                }
                            }
                        }
                    }
                }
                catch (OperationCanceledException) when (bridgeToken.IsCancellationRequested)
                {
                }
                catch
                {
                    Interlocked.Increment(ref rejectedConnectionCount);
                }
            }
        }

        private byte[] InjectAuthorization(byte[] header)
        {
            if (header.Length < 4)
            {
                throw new InvalidDataException("The proxy request header is incomplete.");
            }

            byte[] result = new byte[header.Length + authorizationHeader.Length];
            Buffer.BlockCopy(header, 0, result, 0, header.Length - 2);
            Buffer.BlockCopy(authorizationHeader, 0, result, header.Length - 2, authorizationHeader.Length);
            Buffer.BlockCopy(header, header.Length - 2, result, header.Length - 2 + authorizationHeader.Length, 2);
            return result;
        }

        private static async Task<byte[]> ReadHeaderAsync(Stream stream, CancellationToken token)
        {
            byte[] rented = ArrayPool<byte>.Shared.Rent(MaximumHeaderBytes);
            try
            {
                int count = 0;
                while (count < MaximumHeaderBytes)
                {
                    int read = await stream.ReadAsync(rented.AsMemory(count, 1), token).ConfigureAwait(false);
                    if (read == 0)
                    {
                        throw new EndOfStreamException("The proxy client closed before completing its request header.");
                    }

                    count += read;
                    if (count >= 4 && rented[count - 4] == 13 && rented[count - 3] == 10 &&
                        rented[count - 2] == 13 && rented[count - 1] == 10)
                    {
                        byte[] result = new byte[count];
                        Buffer.BlockCopy(rented, 0, result, 0, count);
                        return result;
                    }
                }

                throw new InvalidDataException("The proxy request header exceeded the bridge limit.");
            }
            finally
            {
                CryptographicOperations.ZeroMemory(rented);
                ArrayPool<byte>.Shared.Return(rented);
            }
        }

        private static bool ContainsProxyAuthorization(byte[] header)
        {
            string text = Encoding.ASCII.GetString(header);
            return text.IndexOf("\r\nProxy-Authorization:", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static int FindTcpOwnerProcessId(int localPort, int remotePort)
        {
            int size = 0;
            uint result = GetExtendedTcpTable(IntPtr.Zero, ref size, false, AddressFamilyInterNetwork, TcpTableOwnerPidAll, 0);
            if (result != 0 && result != 122)
            {
                return 0;
            }

            IntPtr buffer = Marshal.AllocHGlobal(size);
            try
            {
                result = GetExtendedTcpTable(buffer, ref size, false, AddressFamilyInterNetwork, TcpTableOwnerPidAll, 0);
                if (result != 0)
                {
                    return 0;
                }

                int count = Marshal.ReadInt32(buffer);
                IntPtr rowPointer = IntPtr.Add(buffer, sizeof(uint));
                int rowSize = Marshal.SizeOf<MibTcpRowOwnerPid>();
                for (int index = 0; index < count; index++)
                {
                    MibTcpRowOwnerPid row = Marshal.PtrToStructure<MibTcpRowOwnerPid>(rowPointer);
                    if (DecodePort(row.LocalPort) == localPort && DecodePort(row.RemotePort) == remotePort &&
                        row.RemoteAddress == 0x0100007F)
                    {
                        return unchecked((int)row.OwningProcessId);
                    }

                    rowPointer = IntPtr.Add(rowPointer, rowSize);
                }

                return 0;
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }

        private static int DecodePort(uint networkPort)
        {
            return (ushort)IPAddress.NetworkToHostOrder(unchecked((short)(networkPort & 0xFFFF)));
        }

        private static bool IsProcessOrDescendant(int processId, int rootProcessId)
        {
            if (processId <= 0 || rootProcessId <= 0)
            {
                return false;
            }

            try
            {
                using (Process root = Process.GetProcessById(rootProcessId))
                {
                    if (root.HasExited)
                    {
                        return false;
                    }
                }
            }
            catch
            {
                return false;
            }

            Dictionary<int, int> parents = SnapshotProcessParents();
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
                throw new ObjectDisposedException(nameof(AceOutpostDesktopProxyBridge));
            }
        }

        public void Dispose()
        {
            if (Interlocked.Exchange(ref disposed, 1) != 0)
            {
                return;
            }

            cancellation.Cancel();
            listener.Stop();
            rootReady.Set();
            try
            {
                acceptLoop?.Wait(TimeSpan.FromSeconds(2));
                Task[] active = connections.Values.ToArray();
                if (active.Length > 0)
                {
                    Task.WaitAll(active, TimeSpan.FromSeconds(2));
                }
            }
            catch
            {
            }
            finally
            {
                CryptographicOperations.ZeroMemory(authorizationHeader);
                rootReady.Dispose();
                cancellation.Dispose();
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MibTcpRowOwnerPid
        {
            public uint State;
            public uint LocalAddress;
            public uint LocalPort;
            public uint RemoteAddress;
            public uint RemotePort;
            public uint OwningProcessId;
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
            public int BasePriority;
            public uint Flags;

            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
            public string ExeFile;
        }

        [DllImport("iphlpapi.dll", SetLastError = true)]
        private static extern uint GetExtendedTcpTable(
            IntPtr tcpTable,
            ref int size,
            bool order,
            int addressFamily,
            int tableClass,
            uint reserved);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint processId);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool Process32First(IntPtr snapshot, ref ProcessEntry32 entry);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool Process32Next(IntPtr snapshot, ref ProcessEntry32 entry);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);
    }
}
'@
}
