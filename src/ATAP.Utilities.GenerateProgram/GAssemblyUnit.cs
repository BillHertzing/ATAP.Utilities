using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GAssemblyUnit : IGAssemblyUnit {
    public GAssemblyUnit(string gName = default, string gRelativePath = default,
      IGProjectUnit gProjectUnit = default,
      Dictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit> gCompilationUnits = default,
      Dictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit> gPropertiesUnits = default,
      Dictionary<IPhilote<IGResourceUnit>, IGResourceUnit> gResourceUnits = default,
      IGPatternReplacement gPatternReplacement = default,
      IGComment gComment = default
    ) {
      GName = gName == default ? "" : gName;
      GRelativePath = gRelativePath == default ? "" : gRelativePath;
      GProjectUnit = gProjectUnit == default? new GProjectUnit(GName) : gProjectUnit;
      GCompilationUnits = gCompilationUnits == default ? new Dictionary<Philote<GCompilationUnit>, GCompilationUnit>() : gCompilationUnits;
      GPropertiesUnits = gPropertiesUnits == default ? new Dictionary<Philote<GPropertiesUnit>, GPropertiesUnit>() : gPropertiesUnits;
      GResourceUnits = gResourceUnits == default ? new Dictionary<Philote<GResourceUnit>, GResourceUnit>() : gResourceUnits;
      GComment = gComment == default? new GComment() : gComment;
      GPatternReplacement = gPatternReplacement == default? new GPatternReplacement() : gPatternReplacement;
      Philote = new Philote<GAssemblyUnit>();
    }

    public string GName { get; init; }
    public string GRelativePath { get; init; }
    public IGProjectUnit GProjectUnit { get; init; }
    public Dictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit> GCompilationUnits { get; init; }
    public Dictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit> GPropertiesUnits { get; init; }
    public Dictionary<IPhilote<IGResourceUnit>, IGResourceUnit> GResourceUnits { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGAssemblyUnit> Philote { get; init; }

  }
}
