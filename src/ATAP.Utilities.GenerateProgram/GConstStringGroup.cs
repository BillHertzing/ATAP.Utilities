using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GConstStringGroupId<TValue> : AbstractStronglyTypedId<TValue>, IGConstStringGroupId<TValue> where TValue : notnull {}
  public class GConstStringGroup<TValue> : IGConstStringGroup<TValue> where TValue : notnull {
    public GConstStringGroup(string gName = "", IDictionary<IGConstStringId<TValue>, IGConstString<TValue>> gConstStrings = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GConstStrings = gConstStrings == default ? new Dictionary<IGConstStringId<TValue>, IGConstString<TValue>>() : gConstStrings;
      Id = new GConstStringGroupId<TValue>();
    }
    public string GName { get; init; }
    public IDictionary<IGConstStringId<TValue>, IGConstString<TValue>> GConstStrings { get; init; }
    public  IGConstStringGroupId Id { get; init; }

  }
}






