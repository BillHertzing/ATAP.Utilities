using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram
{
  public interface IGAssemblyUnit
  {
     string GName { get; init; }
    string GRelativePath { get; init; }
    IGProjectUnit GProjectUnit { get; init; }
    Dictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit> GCompilationUnits { get; init; }
    Dictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit> GPropertiesUnits { get; init; }
    Dictionary<IPhilote<IGResourceUnit>, IGResourceUnit> GResourceUnits { get; init; }
    IGPatternReplacement GPatternReplacement { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGAssemblyUnit> Philote { get; init; }
  }
}
