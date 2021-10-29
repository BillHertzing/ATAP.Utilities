using System.Reflection;

// ATAP.Utilities.BuildTooling.targets will update the build (date), and revision fields each time a new build occurs
[assembly:AssemblyFileVersion("0.1.7964.1621")]
// ATAP.Utilities.BuildTooling.targets will update the AssemblyInformationalVersion field each time a new build occurs
[assembly:AssemblyInformationalVersion("0.1.0-Alpha-000")]
[assembly:AssemblyVersion("0.1.0")]
// When building with the Trace symbol defined, turn on ETW logging for Method Entry, Method Exit, and Exceptions
#if TRACE
  [assembly: ATAP.Utilities.ETW.ETWLogAttribute()]
#endif

