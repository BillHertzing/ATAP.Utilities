using System;
using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

    // ToDo:  Add GDescription to the AssemblyUnit

  public record GAssemblyUnitSignil : IGAssemblyUnitSignil {
    public GAssemblyUnitSignil(string gName = default, string gRelativePath = default,
    IGProjectUnit gProjectUnit = default,
      IDictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit>  gCompilationUnits = default,
      IDictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit> gPropertiesUnits = default,
      IDictionary<IPhilote<IGResourceUnit>, IGResourceUnit> gResourceUnits  = default,
      GPatternReplacement gPatternReplacement = default, GComment gComment = default) {
      GName = gName == default ? "" : gName;
      // ToDo:  Add GDescription to the AssemblyUnit
      GProjectUnit = gProjectUnit == default ? new GProjectUnit() : gProjectUnit;
      GCompilationUnits = gCompilationUnits == default ? new Dictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit>() : gCompilationUnits;
      GPropertiesUnits = gPropertiesUnits == default ? new Dictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit>() : gPropertiesUnits;
      GResourceUnits = gResourceUnits == default ? new Dictionary<IPhilote<IGResourceUnit>, IGResourceUnit>() : gResourceUnits;

      GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<IGAssemblyUnitSignil>();
    }
    public string GName { get; init; }
    // ToDo:  Add GDescription to the AssemblyUnit public string GDescription { get; init; }
    public string GRelativePath { get; init; }
     public IGProjectUnit GProjectUnit { get; init; }
    public IDictionary<IPhilote<IGCompilationUnit>, IGCompilationUnit> GCompilationUnits { get; init; }
    public IDictionary<IPhilote<IGPropertiesUnit>, IGPropertiesUnit> GPropertiesUnits { get; init; }
    public IDictionary<IPhilote<IGResourceUnit>, IGResourceUnit> GResourceUnits { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGAssemblyUnitSignil> Philote { get; init; }

  }
}
