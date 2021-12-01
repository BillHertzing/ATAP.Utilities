using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GMethodId<TValue> : AbstractStronglyTypedId<TValue>, IGMethodId<TValue> where TValue : notnull {}
  public class GMethod<TValue> : IGMethod<TValue> where TValue : notnull {
    public GMethod(IGMethodDeclaration gDeclaration = default, IGBody gBody = default,
      IGComment gComment = default, bool isForInterface = false,
      IGStateConfiguration gStateConfiguration = default) {
      GDeclaration = gDeclaration == default ? new GMethodDeclaration() : gDeclaration;
      GBody = gBody == default ? new GBody() : gBody;
      GComment = gComment == default ? new GComment() : gComment;
      IsForInterface = isForInterface;
      GStateConfiguration = gStateConfiguration == default ? new GStateConfiguration() : gStateConfiguration;
      Id = new GMethodId<TValue>();
    }
    public IGMethodDeclaration GDeclaration { get; init; }
    public IGBody GBody { get; init; }
    public IGComment GComment { get; init; }
    public bool IsForInterface { get; init; }
    public IGStateConfiguration GStateConfiguration { get; init; }
    public  IGMethodId Id { get; init; }
  }
}






