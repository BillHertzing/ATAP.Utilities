using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GResourceItemId<TValue> : AbstractStronglyTypedId<TValue>, IGResourceItemId<TValue> where TValue : notnull {}
  public class GResourceItem<TValue> : IGResourceItem<TValue> where TValue : notnull {
    public GResourceItem(string gName, string gValue, string? gComment = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GValue = gValue ?? throw new ArgumentNullException(nameof(gValue));
      GComment = gComment == default ? "" : gComment;
      Id = new GResourceItemId<TValue>();
    }

    public string GName { get; init; }
    public string GValue { get; init; }
    public string? GComment { get; init; }
    public  IGResourceItemId Id { get; init; }
  }
}






