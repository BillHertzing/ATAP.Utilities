using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GEnumerationMemberId<TValue> : AbstractStronglyTypedId<TValue>, IGEnumerationMemberId<TValue> where TValue : notnull {}
  public class GEnumerationMember<TValue> : IGEnumerationMember<TValue> where TValue : notnull {
    public GEnumerationMember(string gName = "", int? gValue = default,
      IDictionary<IGAttributeId<TValue>, IGAttribute<TValue>> gAttributes = default,
      IDictionary<IGAttributeGroupId<TValue>, IGAttributeGroup<TValue>> gAttributeGroups = default,
      GComment gComment = default
      ) {
      GName = gName;
      GValue = gValue;
      GAttributes = gAttributes == default ? new Dictionary<IGAttributeId<TValue>, IGAttribute<TValue>>() : gAttributes;
      GAttributeGroups = gAttributeGroups == default ? new Dictionary<IGAttributeGroupId<TValue>, IGAttributeGroup<TValue>>() : gAttributeGroups;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GEnumerationMemberId<TValue>();
    }

    public string GName { get; init; }
    // ToDo: support for enumeration member types other than int
    public int? GValue { get; init; }
    public IDictionary<IGAttributeId<TValue>, IGAttribute<TValue>> GAttributes { get; init; }
    public IDictionary<IGAttributeGroupId<TValue>, IGAttributeGroup<TValue>> GAttributeGroups { get; init; }
    public IGComment GComment { get; init; }
    public  IGEnumerationMemberId Id { get; init; }

  }
}







