using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

#if NETDESKTOP
using System.ComponentModel;
#endif
// ATAP.Utilities.BuildTooling.targets will update the build (date), and revision fields each time a new build occurs
[assembly:AssemblyFileVersion("0.1.7976.6265")]
// ATAP.Utilities.BuildTooling.targets will update the AssemblyInformationalVersion field each time a new build occurs
[assembly:AssemblyInformationalVersion("0.1.0-Alpha-035")]
[assembly:AssemblyVersion("0.1.0")]
// The following GUID is for the ID of the typelib if this project is exposed to COM
[assembly: Guid("FB2917AC-BDCB-4012-9130-E2EDA9CA7899")]
// When building with the Trace symbol defined, turn on ETW logging for Method Entry, Method Exit, and Exceptions
#region Support public init only setters on Net Desktop runtime
#if NETDESKTOP
// Add IsExternalInit if the TargetFramework is a Net Desktop runtime
namespace System.Runtime.CompilerServices {
  [EditorBrowsable(EditorBrowsableState.Never)]
  internal static class IsExternalInit { }
}
#endif
#endregion
