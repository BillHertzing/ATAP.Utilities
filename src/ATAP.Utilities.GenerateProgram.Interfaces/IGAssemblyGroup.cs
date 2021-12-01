using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram
{
  public interface IGAssemblyGroup
  {
    string GName { get; init; }
    string GDescription { get; init; }
    string GRelativePath { get; init; }
    IDictionary<IPhilote<IGAssemblyUnit>, IGAssemblyUnit> GAssemblyUnits { get; init; }
    IGPatternReplacement GPatternReplacement { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGAssemblyGroup> Philote { get; init; }
  }
}

