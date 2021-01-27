using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGAssemblyUnitSignil  {
    string GName { get; init; }
    // ToDo:  Add GDescription to the AssemblyUnit
    string GRelativePath { get; init; }
    IDictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit> GCompilationUnits { get; init; }
    IDictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit> GPropertiesUnits { get; init; }
    IDictionary<IPhilote<IGResourceUnit>, IGResourceUnit> GResourceUnits { get; init; }
    IGPatternReplacement GPatternReplacement { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGAssemblyUnitSignil> Philote { get; init; }
  }
}
