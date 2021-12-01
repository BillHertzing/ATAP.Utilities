using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GAttributeId<TValue> : AbstractStronglyTypedId<TValue>, IGAttributeId<TValue> where TValue : notnull {}
  public class GAttribute<TValue> : IGAttribute<TValue> where TValue : notnull {
    public GAttribute(string gName = "", string gValue = "",
      IGComment gComment = default
      ) {
      GName = gName;
      GValue = gValue;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GAttributeId<TValue>();
    }

    public string GName { get; init; }
    public string GValue { get; init; }
    public IGComment GComment { get; init; }
    public  IGAttributeId Id { get; init; }
  }
}






