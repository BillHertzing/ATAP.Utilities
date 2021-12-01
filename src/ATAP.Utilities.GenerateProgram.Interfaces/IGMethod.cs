using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGMethodId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGMethod<TValue> where TValue : notnull {
    IGMethodDeclaration GDeclaration { get; init; }
    IGBody GBody { get; init; }
    IGComment GComment { get; init; }
    bool IsForInterface { get; init; }
    IGStateConfiguration GStateConfiguration { get; init; }
    IGMethodId<TValue> Id { get; init; }
  }
}


