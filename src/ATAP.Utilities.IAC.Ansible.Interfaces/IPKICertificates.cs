using System.Collections.Generic;

#pragma warning disable IDE0130 // Namespace does not match folder structure
namespace ATAP.Utilities.IAC.Ansible {
#pragma warning restore IDE0130 // Namespace does not match folder structure
  public interface IPKICertificates {
    Dictionary<string, string> PKICertificates { get; }
  }
}
