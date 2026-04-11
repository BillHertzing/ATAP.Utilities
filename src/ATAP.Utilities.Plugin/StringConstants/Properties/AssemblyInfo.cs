using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

#if NETDESKTOP || NETCOREAPP3_1 || NETSTANDARD
using System.ComponentModel;
#endif
[assembly:AssemblyFileVersion("0.1.9597.8194")]
[assembly:AssemblyInformationalVersion("0.1.0-Alpha-008")]
[assembly:AssemblyVersion("0.1.0")]
[assembly: Guid("C3D4E5F6-A7B8-4C03-D4E5-F6A7B8C9D0E1")]
#if TRACE
[assembly: ATAP.Utilities.ETW.ETWLogAttribute()]
#endif
#region Support public init only setters on Net Desktop runtime
#if NETDESKTOP || NETCOREAPP3_1 || NETSTANDARD
namespace System.Runtime.CompilerServices {
  [EditorBrowsable(EditorBrowsableState.Never)]
  internal static class IsExternalInit { }
}
#endif
#endregion
