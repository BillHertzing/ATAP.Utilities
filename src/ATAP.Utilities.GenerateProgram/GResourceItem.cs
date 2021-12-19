using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GResourceItemId<TValue> : AbstractStronglyTypedId<TValue>, IGResourceItemId<TValue> where TValue : notnull {}
  public class GResourceItem<TValue> : IGResourceItem<TValue> where TValue : notnull {
    public GResourceItem(string gName, string gValue, GComment<TValue>? gComment = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GValue = gValue ?? throw new ArgumentNullException(nameof(gValue));
      GComment = gComment;
      Id = new GResourceItemId<TValue>();
    }

    public string GName { get; init; }
    public string GValue { get; init; }
    public IGComment<TValue>? GComment { get; init; }
    public  IGResourceItemId<TValue> Id { get; init; }
  }
}






