using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
 public interface IGAssemblyGroupSignil  {
    string GName { get; init; }
    string GDescription { get; init; }
    string GRelativePath { get; init; }
    bool HasInterfacesAssembly { get; init; }
    IDictionary<IPhilote<IGAssemblyUnit>, IGAssemblyUnit> GAssemblyUnits { get; init; }
    IGPatternReplacement GPatternReplacement { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGAssemblyGroupSignil> Philote { get; init; }
  }
}
