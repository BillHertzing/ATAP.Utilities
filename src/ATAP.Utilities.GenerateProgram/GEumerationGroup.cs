using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GEnumerationGroupId<TValue> : AbstractStronglyTypedId<TValue>, IGEnumerationGroupId<TValue> where TValue : notnull {}
  public class GEnumerationGroup<TValue> : IGEnumerationGroup<TValue> where TValue : notnull {
    public GEnumerationGroup(string gName = default, IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>> gEnumerations = default) {
      GName = gName == default ? "" : gName;
      GEnumerations = gEnumerations == default ? new Dictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>>() : gEnumerations;
      Id = new GEnumerationGroupId<TValue>();
    }

    public string GName { get; init; }
    public IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>> GEnumerations { get; init; }
    public  IGEnumerationGroupId Id { get; init; }
  }
}






