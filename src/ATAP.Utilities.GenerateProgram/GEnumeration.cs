using System;
using System.Collections.Generic;
//using System.Management.Instrumentation;
using ATAP.Utilities.StronglyTypedId;


namespace ATAP.Utilities.GenerateProgram {

  public record GEnumerationId<TValue> : AbstractStronglyTypedId<TValue>, IGEnumerationId<TValue> where TValue : notnull {}
  public class GEnumeration<TValue> : IGEnumeration<TValue> where TValue : notnull {
    public GEnumeration(string gName = default, string gUnderlyingBaseType = default, string gVisibility = default, string gInheritance = default,
      bool isBitFlags = default,
      Dictionary<IGEnumerationMemberId<TValue>, IGEnumerationMember<TValue>> gEnumerationMembers = default,
      Dictionary<IGAttributeId<TValue>, IGAttribute<TValue>> gAttributes = default,
      Dictionary<IGAttributeGroupId<TValue>, IGAttributeGroup<TValue>> gAttributeGroups = default,
      GComment gComment = default
      ) {
      GName = gName == default ? "" : gName;
      GUnderlyingBaseType = gUnderlyingBaseType == default ? "" : gUnderlyingBaseType;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GInheritance = gInheritance == default ? "" : gInheritance; ;
      IsBitFlags = isBitFlags == default ? false : (bool)isBitFlags;
      GEnumerationMembers = gEnumerationMembers == default ? new Dictionary<IGEnumerationMemberId<TValue>, IGEnumerationMember<TValue>>() : gEnumerationMembers;
      GAttributes = gAttributes == default ? new Dictionary<IGAttributeId<TValue>, IGAttribute<TValue>>() : gAttributes;
      GAttributeGroups = gAttributeGroups == default ? new Dictionary<IGAttributeGroupId<TValue>, IGAttributeGroup<TValue>>() : gAttributeGroups;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GEnumerationId<TValue>();
    }
    public string GName { get; init; }
    public string GUnderlyingBaseType { get; init; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; init; }
    public string GVisibility { get; init; }
    public string GInheritance { get; init; }
    public bool IsBitFlags { get; init; }
    public Dictionary<IGEnumerationMemberId<TValue>, IGEnumerationMember<TValue>> GEnumerationMembers { get; init; }
    public Dictionary<IGAttributeId<TValue>, IGAttribute<TValue>> GAttributes { get; init; }
    public Dictionary<IGAttributeGroupId<TValue>, IGAttributeGroup<TValue>> GAttributeGroups { get; init; }
    public IGComment GComment { get; init; }
    public  IGEnumerationId Id { get; init; }

  }
}







