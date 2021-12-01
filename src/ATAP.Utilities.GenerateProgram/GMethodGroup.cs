using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GMethodGroupId<TValue> : AbstractStronglyTypedId<TValue>, IGMethodGroupId<TValue> where TValue : notnull {}
  public class GMethodGroup<TValue> : IGMethodGroup<TValue> where TValue : notnull {
    public GMethodGroup(string gName, IDictionary<IGMethodId<TValue>, IGMethod<TValue>>? gMethods = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GMethods = gMethods == default ? new Dictionary<IGMethodId<TValue>, IGMethod<TValue>>() : gMethods;
      Id = new GMethodGroupId<TValue>();
    }

    public string GName { get; init; }
    public IDictionary<IGMethodId<TValue>, IGMethod<TValue>>? GMethods { get; init; }
    public  IGMethodGroupId Id { get; init; }
  }
}






