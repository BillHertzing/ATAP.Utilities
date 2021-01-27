using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GAssemblyUnit : IGAssemblyUnit {
    public GAssemblyUnit(string gName = default, string gRelativePath = default,
      IGProjectUnit gProjectUnit = default,
      IDictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit> gCompilationUnits = default,
      IDictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit> gPropertiesUnits = default,
      IDictionary<IPhilote<IGResourceUnit>, IGResourceUnit> gResourceUnits = default,
      IGPatternReplacement gPatternReplacement = default,
      IGComment gComment = default
    ) {
      GName = gName == default ? "" : gName;
      GRelativePath = gRelativePath == default ? "" : gRelativePath;
      GProjectUnit = gProjectUnit == default? new GProjectUnit(GName) : gProjectUnit;
      GCompilationUnits = gCompilationUnits == default ? new Dictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit>() : gCompilationUnits;
      GPropertiesUnits = gPropertiesUnits == default ? new Dictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit>() : gPropertiesUnits;
      GResourceUnits = gResourceUnits == default ? new Dictionary<IPhilote<IGResourceUnit>, IGResourceUnit>() : gResourceUnits;
      GComment = gComment == default? new GComment() : gComment;
      GPatternReplacement = gPatternReplacement == default? new GPatternReplacement() : gPatternReplacement;
      Philote = new Philote<IGAssemblyUnit>();
    }

    public GAssemblyUnit(IGAssemblyUnitSignil gAssemblyUnitSignil    ) {
      GName = gAssemblyUnitSignil.GName;
      GRelativePath = gAssemblyUnitSignil.GRelativePath;
      GProjectUnit = gAssemblyUnitSignil.GProjectUnit;
      GCompilationUnits = gAssemblyUnitSignil.GCompilationUnits;
      GPropertiesUnits = gAssemblyUnitSignil.GPropertiesUnits;
      GResourceUnits = gAssemblyUnitSignil.GResourceUnits;
      GComment = gAssemblyUnitSignil.GComment;
      GPatternReplacement = gAssemblyUnitSignil.GPatternReplacement;
      Philote = new Philote<IGAssemblyUnit>();
    }

    public string GName { get; init; }
    public string GRelativePath { get; init; }
    public IGProjectUnit GProjectUnit { get; init; }
    public IDictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit> GCompilationUnits { get; init; }
    public IDictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit> GPropertiesUnits { get; init; }
    public IDictionary<IPhilote<IGResourceUnit>, IGResourceUnit> GResourceUnits { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGAssemblyUnit> Philote { get; init; }

  }
}
