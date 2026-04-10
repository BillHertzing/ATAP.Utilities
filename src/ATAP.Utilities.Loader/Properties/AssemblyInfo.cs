using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

#if NETDESKTOP || NETCOREAPP3_1 || NETSTANDARD
using System.ComponentModel;
#endif
// ATAP.Utilities.BuildTooling.targets will update the build (date), and revision fields each time a new build occurs
[assembly:AssemblyFileVersion("0.1.9596.26639")]
// ATAP.Utilities.BuildTooling.targets will update the AssemblyInformationalVersion field each time a new build occurs
[assembly:AssemblyInformationalVersion("0.1.0-Alpha-013")]
[assembly:AssemblyVersion("0.1.0")]
// The following GUID is for the ID of the typelib if this project is exposed to COM
[assembly: Guid("8cda64fb-b6ea-4045-b141-0d02652f22b9")]
// When building with the Trace symbol defined, turn on ETW logging for Method Entry, Method Exit, and Exceptions
#if TRACE
[assembly: ATAP.Utilities.ETW.ETWLogAttribute()]
#endif
#region Support public init only setters on Net Desktop runtime
#if NETDESKTOP || NETCOREAPP3_1 || NETSTANDARD
