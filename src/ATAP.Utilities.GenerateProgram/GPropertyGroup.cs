using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GPropertyGroupId<TValue> : AbstractStronglyTypedId<TValue>, IGPropertyGroupId<TValue> where TValue : notnull {}
  public class GPropertyGroup<TValue> : IGPropertyGroup<TValue> where TValue : notnull {
    public GPropertyGroup(string gName, IDictionary<IGPropertyId<TValue>, IGProperty<TValue>> gPropertys = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      if (gPropertys == default) {
        GPropertys = new Dictionary<IGPropertyId<TValue>, IGProperty<TValue>>();
      }
      else {
        GPropertys = gPropertys;
      }
      Id = new GPropertyGroupId<TValue>();
    }

    public string GName { get; }
    public IDictionary<IGPropertyId<TValue>, IGProperty<TValue>> GPropertys { get; init; }
    public  IGPropertyGroupId Id { get; init; }

  }
}






