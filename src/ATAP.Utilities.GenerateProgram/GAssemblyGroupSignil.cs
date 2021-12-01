using System;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GAssemblyGroupSignilId<TValue> : AbstractStronglyTypedId<TValue>, IGAssemblyGroupSignilId<TValue> where TValue : notnull {}
  public record GAssemblyGroupSignil<TValue> : IGAssemblyGroupSignil<TValue> where TValue : notnull {
    public GAssemblyGroupSignil(string gName = default, string gDescription = default, string gRelativePath = default,
      IDictionary<IGAssemblyUnitId<TValue>, IGAssemblyUnit<TValue>> gAssemblyUnits = default,
      GPatternReplacement gPatternReplacement = default, GComment gComment = default, bool hasInterfacesAssembly = default) {
      GName = gName == default ? "" : gName;
      GDescription = gDescription == default ? "" : gDescription;
      GRelativePath = gRelativePath == default ? "" : gRelativePath;
      HasInterfacesAssembly = hasInterfacesAssembly == default ? true : hasInterfacesAssembly;
      GAssemblyUnits = gAssemblyUnits == default ? new Dictionary<IGAssemblyUnitId<TValue>, IGAssemblyUnit<TValue>>() : gAssemblyUnits;
      GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GAssemblyGroupSignilId<TValue>();
    }
    public string GName { get; init; }
    public string GDescription { get; init; }
    public string GRelativePath { get; init; }
    public bool HasInterfacesAssembly { get; init; }
    public IDictionary<IGAssemblyUnitId<TValue>, IGAssemblyUnit<TValue>> GAssemblyUnits { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public  IGAssemblyGroupSignilId Id { get; init; }

  }
}






