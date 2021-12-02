using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGEnumerationId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGEnumeration<TValue> where TValue : notnull {
    string GName { get; init; }
    string GUnderlyingBaseType { get; init; }
    string GAccessModifier { get; init; }
    string GVisibility { get; init; }
    string GInheritance { get; init; }
    bool IsBitFlags { get; init; }
    Dictionary<IGEnumerationMemberId<TValue>, IGEnumerationMember<TValue>> GEnumerationMembers { get; init; }
    Dictionary<IGAttributeId<TValue>, IGAttribute<TValue>> GAttributes { get; init; }
    Dictionary<IGAttributeGroupId<TValue>, IGAttributeGroup<TValue>> GAttributeGroups { get; init; }
    IGComment<TValue> GComment { get; init; }
    IGEnumerationId<TValue> Id { get; init; }
  }
}



