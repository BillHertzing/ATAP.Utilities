using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GAssemblyUnitId<TValue> : AbstractStronglyTypedId<TValue>, IGAssemblyUnitId<TValue> where TValue : notnull {}
  public class GAssemblyUnit<TValue> : IGAssemblyUnit<TValue> where TValue : notnull {
    public GAssemblyUnit(string gName = default, string gRelativePath = default,
      IGProjectUnit gProjectUnit = default,
      IDictionary<IGCompilationUnitId<TValue>, IGCompilationUnit<TValue>> gCompilationUnits = default,
      IDictionary<IGPropertiesUnitId<TValue>, IGPropertiesUnit<TValue>> gPropertiesUnits = default,
      IDictionary<IGResourceUnitId<TValue>, IGResourceUnit<TValue>> gResourceUnits = default,
      IGPatternReplacement gPatternReplacement = default,
      IGComment gComment = default
    ) {
      GName = gName == default ? "" : gName;
      GRelativePath = gRelativePath == default ? "" : gRelativePath;
      GProjectUnit = gProjectUnit == default? new GProjectUnit(GName) : gProjectUnit;
      GCompilationUnits = gCompilationUnits == default ? new Dictionary<IGCompilationUnitId<TValue>, IGCompilationUnit<TValue>>() : gCompilationUnits;
      GPropertiesUnits = gPropertiesUnits == default ? new Dictionary<IGPropertiesUnitId<TValue>, IGPropertiesUnit<TValue>>() : gPropertiesUnits;
      GResourceUnits = gResourceUnits == default ? new Dictionary<IGResourceUnitId<TValue>, IGResourceUnit<TValue>>() : gResourceUnits;
      GComment = gComment == default? new GComment() : gComment;
      GPatternReplacement = gPatternReplacement == default? new GPatternReplacement() : gPatternReplacement;
      Id = new GAssemblyUnitId<TValue>();
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
      Id = new IGAssemblyUnitId<TValue>();
    }

    public string GName { get; init; }
    public string GRelativePath { get; init; }
    public IGProjectUnit GProjectUnit { get; init; }
    public IDictionary<IGCompilationUnitId<TValue>, IGCompilationUnit<TValue>> GCompilationUnits { get; init; }
    public IDictionary<IGPropertiesUnitId<TValue>, IGPropertiesUnit<TValue>> GPropertiesUnits { get; init; }
    public IDictionary<IGResourceUnitId<TValue>, IGResourceUnit<TValue>> GResourceUnits { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public  IGAssemblyUnitId Id { get; init; }

  }
}






