using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

// ATAP.Utilities.BuildTooling.targets will update the build (date), and revision fields each time a new build occurs
[assembly:AssemblyFileVersion("0.1.9597.849")]
// ATAP.Utilities.BuildTooling.targets will update the AssemblyInformationalVersion field each time a new build occurs
[assembly:AssemblyInformationalVersion("0.1.0-Alpha-006")]
[assembly:AssemblyVersion("0.1.0")]
// The following GUID is for the ID of the typelib if this project is exposed to COM
[assembly: Guid("A4B5C6D7-E8F9-4D01-E5F6-A7B8C9D0E1F2")]
// When building with the Trace symbol defined, turn on ETW logging for Method Entry, Method Exit, and Exceptions
#if TRACE
[assembly: ATAP.Utilities.ETW.ETWLogAttribute()]
#endif
