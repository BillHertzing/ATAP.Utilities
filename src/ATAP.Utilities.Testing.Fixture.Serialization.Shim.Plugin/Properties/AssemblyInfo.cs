using System.Reflection;
#if NETDESKTOP || NETSTANDARD
using System.ComponentModel;
#endif

// ATAP.Utilities.BuildTooling.targets will update the build (date), and revision fields each time a new build occurs
[assembly:AssemblyFileVersion("1.0.7985.8868")]
// ATAP.Utilities.BuildTooling.targets will update the AssemblyInformationalVersion field each time a new build occurs
[assembly:AssemblyInformationalVersion("1.0.0")]
[assembly:AssemblyVersion("1.0.0")]
#if TRACE
[assembly: ATAP.Utilities.ETW.ETWLogAttribute()]
#endif
#region Support public init only setters on Net Desktop runtime
#if NETDESKTOP || NETSTANDARD
// Add IsExternalInit if the TargetFramework is a Net Desktop runtime
namespace System.Runtime.CompilerServices {
  [EditorBrowsable(EditorBrowsableState.Never)]
  internal static class IsExternalInit { }
}
#endif
#endregion
