using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram
{
  public interface IGAssemblyGroup
  {
    string GName { get; }
    string GDescription { get; }
    string GRelativePath { get; }
    Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit>? GAssemblyUnits { get; }
    GPatternReplacement GPatternReplacement { get; }
    GComment GComment { get; }
    Philote<GAssemblyGroup> Philote { get; }
  }
}
