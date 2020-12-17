using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GAssemblyUnit : IGAssemblyUnit {
    public GAssemblyUnit(string gName = default, string gRelativePath = default,
      IGProjectUnit gProjectUnit = default,
      Dictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit> gCompilationUnits = default,
      Dictionary<Philote<IGPropertiesUnit>, IGPropertiesUnit> gPropertiesUnits = default,
      Dictionary<Philote<IGResourceUnit>,I GResourceUnit> gResourceUnits = default,
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

    public string GName { get; }
    public string GRelativePath { get; }
    public IGProjectUnit GProjectUnit { get; }
    public Dictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit> GCompilationUnits { get; }
    public Dictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit> GPropertiesUnits { get; }
    public Dictionary<IPhilote<GResourceUnit>, IGResourceUnit> GResourceUnits { get; }
    public IGPatternReplacement GPatternReplacement { get; }
    public IGComment GComment { get; }
    public IPhilote<IGAssemblyUnit> Philote { get; }

  }
}
