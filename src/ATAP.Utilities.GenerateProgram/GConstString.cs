using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GConstStringId<TValue> : AbstractStronglyTypedId<TValue>, IGConstStringId<TValue> where TValue : notnull {}
  public class GConstString<TValue> : IGConstString<TValue> where TValue : notnull {
    public GConstString(string gName, string gValue) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GValue = gValue ?? throw new ArgumentNullException(nameof(gValue));
      Id = new GConstStringId<TValue>();
    }

    public string GName { get; init; }
    public string GValue { get; init; }
    public  IGConstStringId Id { get; init; }
  }
}






