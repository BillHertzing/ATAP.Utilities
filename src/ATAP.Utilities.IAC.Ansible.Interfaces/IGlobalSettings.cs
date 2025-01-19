using System.Collections.Generic;

namespace ATAP.Utilities.IAC.Ansible {
  public interface IGlobalSettings {
    Dictionary<string, string> GlobalSettings { get; }
  }
}
