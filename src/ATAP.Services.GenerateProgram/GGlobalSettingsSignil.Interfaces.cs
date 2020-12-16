using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public interface IGGlobalSettingsSignil {
    ICollection<string> TargetFrameworks { get; }
  }
}
