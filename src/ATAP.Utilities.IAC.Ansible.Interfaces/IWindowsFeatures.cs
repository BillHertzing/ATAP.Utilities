using System.Collections.Generic;

namespace ATAP.Utilities.IAC.Ansible {
  public interface IWindowsFeatures {
    Dictionary<string, string> WindowsFeatures { get; }
  }
}
