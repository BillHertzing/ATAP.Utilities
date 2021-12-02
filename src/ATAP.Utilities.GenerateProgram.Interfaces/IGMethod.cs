using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGMethodId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGMethod<TValue> where TValue : notnull {
    IGMethodDeclaration<TValue> GDeclaration { get; init; }
    IGBody<TValue> GBody { get; init; }
    IGComment<TValue> GComment { get; init; }
    bool IsForInterface { get; init; }
    IGStateConfiguration<TValue> GStateConfiguration { get; init; }
    IGMethodId<TValue> Id { get; init; }
  }
}


