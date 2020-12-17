using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram
{
  public interface IGAssemblyGroup
  {
    string GName { get; init; }
    string GDescription { get; init; }
    string GRelativePath { get; init; }
    Dictionary<IPhilote<IGAssemblyUnit>, IGAssemblyUnit> GAssemblyUnits { get; init; }
    IGPatternReplacement GPatternReplacement { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGAssemblyGroup> Philote { get; init; }
  }
}
