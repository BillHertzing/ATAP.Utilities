using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GUsingGroupId<TValue> : AbstractStronglyTypedId<TValue>, IGUsingGroupId<TValue> where TValue : notnull {}
  public class GUsingGroup<TValue> : IGUsingGroup<TValue> where TValue : notnull {
    public GUsingGroup(string gName = "", Dictionary<IGUsingId<TValue>, IGUsing<TValue>> gUsings = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GUsings = gUsings == default ? new Dictionary<IGUsingId<TValue>, IGUsing<TValue>>() : gUsings;
      Id = new GUsingGroupId<TValue>();
    }

    public string GName { get; init; }
    public Dictionary<IGUsingId<TValue>, IGUsing<TValue>> GUsings { get; init; }
    public  IGUsingGroupId Id { get; init; }

  }
}







