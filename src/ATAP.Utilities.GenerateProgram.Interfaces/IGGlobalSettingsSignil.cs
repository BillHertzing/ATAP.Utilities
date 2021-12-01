using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGGlobalSettingsSignil {
    ICollection<string> DefaultTargetFrameworks { get; }
  }
}


