using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GAssemblyGroupId<TValue> : AbstractStronglyTypedId<TValue>, IGAssemblyGroupId<TValue> where TValue : notnull {}
  public class GAssemblyGroup<TValue> : IGAssemblyGroup<TValue> where TValue : notnull {
    public GAssemblyGroup(string gName = "", string gDescription = "", string gRelativePath = "",

      IDictionary<IGAssemblyUnitId<TValue>, IGAssemblyUnit<TValue>> gAssemblyUnits = default,
      IGPatternReplacement gPatternReplacement = default,
      IGComment gComment = default
    ) {
      GName = gName;
      GDescription = gDescription;
      GRelativePath = gRelativePath;
      GAssemblyUnits = gAssemblyUnits == default ? new Dictionary<IGAssemblyUnitId<TValue>, IGAssemblyUnit<TValue>>() : gAssemblyUnits;
      GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GComment = gComment == default ? new GComment() : gComment;

      Id = new GAssemblyGroupId<TValue>();
    }
    public string GName { get; init; }
    public string GDescription { get; init; }
    public string GRelativePath { get; init; }
    public
      IDictionary<IGAssemblyUnitId<TValue>, IGAssemblyUnit<TValue>>? GAssemblyUnits { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public  IGAssemblyGroupId Id { get; init; }

  }
}






