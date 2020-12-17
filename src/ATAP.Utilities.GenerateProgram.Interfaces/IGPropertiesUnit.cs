using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGPropertiesUnit {
    string GName { get; init; }
    string GRelativePath { get; init; }
    string GFileSuffix { get; init; }
    IPhilote<IGPropertiesUnit> Philote { get; init; }
  }
}
