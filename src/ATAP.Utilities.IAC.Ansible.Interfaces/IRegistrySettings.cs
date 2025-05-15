// Registry types are defined in Win32.
// Net 6.0 and higher include these automatically.
// Earlier versions of DotNet will require the Microsoft.Win32 package be added to the project's .csproj file
using Microsoft.Win32;

using System.Collections.Generic;

namespace ATAP.Utilities.IAC.Ansible {

  public interface IRegistryKindValuePair {
    RegistryValueKind RegistryValueKind { get; }
    // a null-terminated string
    string? REG_SZ { get; }
    // a null-terminated string with expandable variables, for example %SystemRoot%
    string? REG_EXPAND_SZ { get; }
    // a string that consist of a string array seperated by null character and terminated with two null chars
    string? REG_MULTI_SZ { get; }
    // unsigned 32 byte integer
    uint? REG_DWORD { get; }
    // unsigned 64 byte integer
    ulong? REG_QWORD { get; }
    // ToDo: add the rest
  }
  public interface IRegistrySetting {
    IDictionary<string, IRegistryKindValuePair> PropertyValueTriplet { get; }
  }
  public interface IRegistrySettings {
    IDictionary<RegistryKey, IRegistrySetting> RegistrySettings { get; }
  }
}
