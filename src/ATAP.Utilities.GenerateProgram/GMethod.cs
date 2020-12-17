using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GMethod : IGMethod {
    public GMethod(IGMethodDeclaration gDeclaration = default, IGBody gBody = default,
      IGComment gComment = default, bool isForInterface = false,
      IGStateConfiguration gStateConfiguration = default) {
      GDeclaration = gDeclaration == default ? new GMethodDeclaration() : gDeclaration;
      GBody = gBody == default ? new GBody() : gBody;
      GComment = gComment == default ? new GComment() : gComment;
      IsForInterface = isForInterface;
      GStateConfiguration = gStateConfiguration == default ? new GStateConfiguration() : gStateConfiguration;
      Philote = new Philote<IGMethod>();
    }
    public IGMethodDeclaration GDeclaration { get; init; }
    public IGBody GBody { get; init; }
    public IGComment GComment { get; init; }
    public bool IsForInterface { get; init; }
    public IGStateConfiguration GStateConfiguration { get; init; }
    public IPhilote<IGMethod> Philote { get; init; }
  }
}
