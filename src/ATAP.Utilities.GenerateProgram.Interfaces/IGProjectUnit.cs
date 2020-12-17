using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGProjectUnit {
    string GName { get; init; }
    string GRelativePath { get; init; }
    string GFileSuffix { get; init; }
    Dictionary<IPhilote<IGResourceUnit>, IGResourceUnit> GResourceUnits { get; init; }
    Dictionary<IPhilote<IGPropertyGroupInProjectUnit>, IGPropertyGroupInProjectUnit> GPropertyGroupInProjectUnits { get; init; }
    Dictionary<IPhilote<IGItemGroupInProjectUnit>, IGItemGroupInProjectUnit> GItemGroupInProjectUnits { get; init; }
    IGPatternReplacement GPatternReplacement { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGProjectUnit> Philote { get; init; }
  }
}
