using System.Reflection;
#if NETSTANDARD2_0 || NETSTANDARD2_1 || NETCOREAPP2_0 || NETCOREAPP2_1 || NETCOREAPP2_2 || NETCOREAPP3_0 || NETCOREAPP3_1 || NET45 || NET451 || NET452 || NET6 || NET461 || NET462 || NET47 || NET471 || NET472 || NET48
using System.ComponentModel;
#endif
// ATAP.Utilities.BuildTooling.targets will update the build (date), and revision fields each time a new build occurs
[assembly:AssemblyFileVersion("0.1.7972.14971")]
// ATAP.Utilities.BuildTooling.targets will update the AssemblyInformationalVersion field each time a new build occurs
[assembly:AssemblyInformationalVersion("0.1.0-Alpha-002")]
[assembly:AssemblyVersion("0.1.0")]
// When building with the Trace symbol defined, turn on ETW logging for Method Entry, Method Exit, and Exceptions
#if TRACE
[assembly: ATAP.Utilities.ETW.ETWLogAttribute()]
#endif
#region Support public init only setters on frameworks older than net 5.0
#if NETSTANDARD2_0 || NETSTANDARD2_1 || NETCOREAPP2_0 || NETCOREAPP2_1 || NETCOREAPP2_2 || NETCOREAPP3_0 || NETCOREAPP3_1 || NET45 || NET451 || NET452 || NET6 || NET461 || NET462 || NET47 || NET471 || NET472 || NET48
// ReSharper disable once CheckNamespace
namespace System.Runtime.CompilerServices {
  [EditorBrowsable(EditorBrowsableState.Never)]
  internal static class IsExternalInit { }
}
#endif
#endregion
