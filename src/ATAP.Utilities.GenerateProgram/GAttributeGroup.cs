using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GAttributeGroupId<TValue> : AbstractStronglyTypedId<TValue>, IGAttributeGroupId<TValue> where TValue : notnull {}
  public class GAttributeGroup<TValue> : IGAttributeGroup<TValue> where TValue : notnull {
    public GAttributeGroup(string gName = "", Dictionary<IGAttributeId<TValue>, IGAttribute<TValue>> gAttributes = default,
      GComment gComment = default
    ) {
      GName = gName;
      GAttributes = gAttributes == default ? new Dictionary<IGAttributeId<TValue>, IGAttribute<TValue>>() : gAttributes;
      GComment = gComment == default ? new GComment() : gComment;

      Id = new GAttributeGroupId<TValue>();
    }
    public string GName { get; init; }
    public Dictionary<IGAttributeId<TValue>, IGAttribute<TValue>> GAttributes { get; init; }
    public IGComment GComment { get; init; }
    public  IGAttributeGroupId Id { get; init; }
  }
}







