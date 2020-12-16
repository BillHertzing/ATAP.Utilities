using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram
{
  public interface IGAssemblyUnit
  {
    string GName { get; }
    string GRelativePath { get; }
    GProjectUnit GProjectUnit { get; }
    Dictionary<Philote<GCompilationUnit>, GCompilationUnit> GCompilationUnits { get; }
    Dictionary<Philote<GPropertiesUnit>, GPropertiesUnit> GPropertiesUnits { get; }
    Dictionary<Philote<GResourceUnit>, GResourceUnit> GResourceUnits { get; }
    GPatternReplacement GPatternReplacement { get; }
    GComment GComment { get; }
    Philote<GAssemblyUnit> Philote { get; }
  }
}
