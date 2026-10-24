if (-not ('ATAP.GeneratedRemediation.NativePathMetadataV1' -as [type])) {
  Add-Type -Language CSharp -PassThru -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace ATAP.GeneratedRemediation
{
    // Minimal synchronous metadata interop, not a general filesystem API.
    [StructLayout(LayoutKind.Sequential)]
    public struct AttributeTagInfoV1
    {
        public uint FileAttributes;
        public uint ReparseTag;
    }

    public sealed class MetadataResultV1
    {
        public bool Success;
        public uint Attributes;
        public uint ReparseTag;
        public int ErrorCode;
        public bool HandleOpened;
        public bool HandleClosed;
    }

    public static class NativePathMetadataV1
    {
        public const uint DesiredAccess = 0;
        public const uint ShareMode = 7;
        public const uint Disposition = 3;
        public const uint Flags = 0x02200000;
        public const int InformationClass = 9;

        [DllImport("kernel32.dll", EntryPoint = "CreateFileW", CharSet = CharSet.Unicode,
            ExactSpelling = true, SetLastError = true)]
        private static extern SafeFileHandle Open(string path, uint access, uint share,
            IntPtr security, uint disposition, uint flags, IntPtr template);

        [DllImport("kernel32.dll", EntryPoint = "GetFileInformationByHandleEx",
            ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool Query(SafeFileHandle handle, int informationClass,
            out AttributeTagInfoV1 information, uint size);

        public static MetadataResultV1 Read(string path)
        {
            var result = new MetadataResultV1();
            SafeFileHandle handle = null;
            try
            {
                handle = Open(path, DesiredAccess, ShareMode, IntPtr.Zero,
                    Disposition, Flags, IntPtr.Zero);
                int openError = Marshal.GetLastWin32Error();
                if (handle.IsInvalid)
                {
                    result.ErrorCode = openError;
                    return result;
                }
                result.HandleOpened = true;
                AttributeTagInfoV1 info;
                bool success = Query(handle, InformationClass, out info,
                    (uint)Marshal.SizeOf<AttributeTagInfoV1>());
                int queryError = Marshal.GetLastWin32Error();
                if (!success)
                {
                    result.ErrorCode = queryError;
                    return result;
                }
                result.Attributes = info.FileAttributes;
                result.ReparseTag = info.ReparseTag;
                result.Success = true;
                return result;
            }
            finally
            {
                if (handle != null)
                {
                    handle.Dispose();
                    result.HandleClosed = handle.IsClosed;
                }
            }
        }
    }
}
'@
}
