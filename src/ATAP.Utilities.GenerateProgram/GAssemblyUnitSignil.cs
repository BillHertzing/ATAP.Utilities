using System;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

    // ToDo:  Add GDescription to the AssemblyUnit

  public record GAssemblyUnitSignilId<TValue> : AbstractStronglyTypedId<TValue>, IGAssemblyUnitSignilId<TValue> where TValue : notnull {}
  public record GAssemblyUnitSignil<TValue> : IGAssemblyUnitSignil<TValue> where TValue : notnull {
    public GAssemblyUnitSignil(string gName = default, string gRelativePath = default,
    IGProjectUnit gProjectUnit = default,
      IDictionary<IGCompilationUnitId<TValue>, IGCompilationUnit<TValue>>  gCompilationUnits = default,
      IDictionary<IGPropertiesUnitId<TValue>, IGPropertiesUnit<TValue>> gPropertiesUnits = default,
      IDictionary<IGResourceUnitId<TValue>, IGResourceUnit<TValue>> gResourceUnits  = default,
      GPatternReplacement gPatternReplacement = default, GComment gComment = default) {
      GName = gName == default ? "" : gName;
      // ToDo:  Add GDescription to the AssemblyUnit
      GProjectUnit = gProjectUnit == default ? new GProjectUnit() : gProjectUnit;
      GCompilationUnits = gCompilationUnits == default ? new Dictionary<IGCompilationUnitId<TValue>, IGCompilationUnit<TValue>>() : gCompilationUnits;
      GPropertiesUnits = gPropertiesUnits == default ? new Dictionary<IGPropertiesUnitId<TValue>, IGPropertiesUnit<TValue>>() : gPropertiesUnits;
      GResourceUnits = gResourceUnits == default ? new Dictionary<IGResourceUnitId<TValue>, IGResourceUnit<TValue>>() : gResourceUnits;

      GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GAssemblyUnitSignilId<TValue>();
    }
    public string GName { get; init; }
    // ToDo:  Add GDescription to the AssemblyUnit public string GDescription { get; init; }
    public string GRelativePath { get; init; }
     public IGProjectUnit GProjectUnit { get; init; }
    public IDictionary<IGCompilationUnitId<TValue>, IGCompilationUnit<TValue>> GCompilationUnits { get; init; }
    public IDictionary<IGPropertiesUnitId<TValue>, IGPropertiesUnit<TValue>> GPropertiesUnits { get; init; }
    public IDictionary<IGResourceUnitId<TValue>, IGResourceUnit<TValue>> GResourceUnits { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public  IGAssemblyUnitSignilId Id { get; init; }

  }
}






