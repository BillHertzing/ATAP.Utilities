using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGGlobalSettingsSignil {
    ICollection<string> TargetFrameworks { get; }
  }
}
