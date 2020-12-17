using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public record GAssemblyGroupSignil : IGAssemblyGroupSignil {
    public GAssemblyGroupSignil(string gName = default, string gDescription = default, string gRelativePath = default,
      IDictionary<IPhilote<IGAssemblyUnit>, IGAssemblyUnit> gAssemblyUnits = default,
      GPatternReplacement gPatternReplacement = default, GComment gComment = default, bool hasInterfacesAssembly = default) {
      GName = gName == default ? "" : gName;
      GDescription = gDescription == default ? "" : gDescription;
      GRelativePath = gRelativePath == default ? "" : gRelativePath;
      HasInterfacesAssembly = HasInterfacesAssembly == default ? true : hasInterfacesAssembly;
      GAssemblyUnits = gAssemblyUnits == default ? new Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit>() : gAssemblyUnits;
      GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GComment = gComment == default ? new GComment() : gComment; 
      Philote = new Philote<GAssemblyGroupSignil>();
    }
    public string GName { get; init; }
    public string GDescription { get; init; }
    public string GRelativePath { get; init; }
    public bool HasInterfacesAssembly { get; init; }
    public IDictionary<IPhilote<IGAssemblyUnit>, IGAssemblyUnit> GAssemblyUnits { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGAssemblyGroupSignil> Philote { get; init; }

  }
}
