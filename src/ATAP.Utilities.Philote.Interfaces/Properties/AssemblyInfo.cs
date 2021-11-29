using System.Reflection;
#if NETDESKTOP || NETCOREAPP3_1 || NETSTANDARD
using System.ComponentModel;
#endif

// ATAP.Utilities.BuildTooling.targets will update the build (date), and revision fields each time a new build occurs
[assembly:AssemblyFileVersion("0.1.8003.11087")]
// ATAP.Utilities.BuildTooling.targets will update the AssemblyInformationalVersion field each time a new build occurs
[assembly:AssemblyInformationalVersion("0.1.0-Alpha-002")]
[assembly:AssemblyVersion("0.1.0")]
#region Support public init only setters on Net Desktop runtime
#if NETDESKTOP || NETCOREAPP3_1 || NETSTANDARD
// Add IsExternalInit if the TargetFramework is a Net Desktop runtime
namespace System.Runtime.CompilerServices {
  [EditorBrowsable(EditorBrowsableState.Never)]
  internal static class IsExternalInit { }
}
#endif
#endregion
