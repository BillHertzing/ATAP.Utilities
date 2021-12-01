using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram
{
  public interface IGAssemblyUnit
  {
     string GName { get; init; }
    string GRelativePath { get; init; }
    IGProjectUnit GProjectUnit { get; init; }
    IDictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit> GCompilationUnits { get; init; }
    IDictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit> GPropertiesUnits { get; init; }
    IDictionary<IPhilote<IGResourceUnit>, IGResourceUnit> GResourceUnits { get; init; }
    IGPatternReplacement GPatternReplacement { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGAssemblyUnit> Philote { get; init; }
  }
}

