using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
 public interface IGAssemblyGroupSignil  {
    string GName { get; }
    string GDescription { get; }
    string GRelativePath { get; }
    bool HasInterfacesAssembly { get; }
    Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit> GAssemblyUnits { get; }
    GPatternReplacement GPatternReplacement { get; }
    GComment GComment { get; }
    //Philote = new Philote<GAssemblyGroupSignil>();

  }
}
