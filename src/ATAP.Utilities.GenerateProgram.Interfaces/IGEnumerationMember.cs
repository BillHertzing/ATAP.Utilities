using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGEnumerationMemberId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGEnumerationMember<TValue> where TValue : notnull {
    string GName { get; init; }
    int? GValue { get; init; }
    IDictionary<IGAttributeId<TValue>, IGAttribute<TValue>> GAttributes { get; init; }
    IDictionary<IGAttributeGroupId<TValue>, IGAttributeGroup<TValue>> GAttributeGroups { get; init; }
    IGComment<TValue> GComment { get; init; }
    IGEnumerationMemberId<TValue> Id { get; init; }
  }
}



