using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GPropertyId<TValue> : AbstractStronglyTypedId<TValue>, IGPropertyId<TValue> where TValue : notnull {}
  public class GProperty<TValue> : IGProperty<TValue> where TValue : notnull {
    public GProperty(string gName = default, string gType = default, string gAccessors = "{ get; set; }", string? gVisibility = default) {
      GName = gName == default ? "" : gName;
      GType = gType == default ? "" : gType;
      GAccessors = gAccessors ?? throw new ArgumentNullException(nameof(gAccessors));
      GVisibility = gVisibility == default ? "" : gVisibility;
      Id = new GPropertyId<TValue>();
    }

    public string GName { get; }
    public string GType { get; }
    public string GAccessors { get; }
    public string? GVisibility { get; }
    public  IGPropertyId Id { get; init; }

  }
}







