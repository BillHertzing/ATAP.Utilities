using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GDelegateGroupId<TValue> : AbstractStronglyTypedId<TValue>, IGDelegateGroupId<TValue> where TValue : notnull {}
  public class GDelegateGroup<TValue> : IGDelegateGroup<TValue> where TValue : notnull {
    public GDelegateGroup(string gName, Dictionary<IGDelegateId<TValue>, IGDelegate<TValue>>? gDelegates = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GDelegates = gDelegates == default ? new Dictionary<IGDelegateId<TValue>, IGDelegate<TValue>>() : gDelegates;
      Id = new GDelegateGroupId<TValue>();
    }

    public string GName { get; init; }
    public Dictionary<IGDelegateId<TValue>, IGDelegate<TValue>>? GDelegates { get; init; }
    public  IGDelegateGroupId Id { get; init; }
  }
}







