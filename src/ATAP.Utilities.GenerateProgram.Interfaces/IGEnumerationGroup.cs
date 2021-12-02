using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGEnumerationGroupId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGEnumerationGroup<TValue> where TValue : notnull {
    string GName { get; init; }
    IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>> GEnumerations { get; init; }
    IGEnumerationGroupId<TValue> Id { get; init; }
  }
}



