using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGMethod {
    IGMethodDeclaration GDeclaration { get; init; }
    IGBody GBody { get; init; }
    IGComment GComment { get; init; }
    bool IsForInterface { get; init; }
    IGStateConfiguration GStateConfiguration { get; init; }
    IPhilote<IGMethod> Philote { get; init; }
  }
}
