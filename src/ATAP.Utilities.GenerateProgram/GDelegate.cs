using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GDelegateId<TValue> : AbstractStronglyTypedId<TValue>, IGDelegateId<TValue> where TValue : notnull {}
  public class GDelegate<TValue> : IGDelegate<TValue> where TValue : notnull {
    public GDelegate(IGDelegateDeclaration gDelegateDeclaration = default, IGComment gComment = default) {
      GDelegateDeclaration = gDelegateDeclaration == default ? new GDelegateDeclaration() : gDelegateDeclaration;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GDelegateId<TValue>();
    }

    public IGDelegateDeclaration GDelegateDeclaration { get; init; }
    public IGComment GComment { get; init; }
    public  IGDelegateId Id { get; init; }
  }
}







