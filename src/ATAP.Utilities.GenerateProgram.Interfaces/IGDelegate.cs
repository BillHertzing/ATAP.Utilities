using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGDelegateId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGDelegate<TValue> where TValue : notnull {
    IGDelegateDeclaration GDelegateDeclaration { get; init; }
    IGComment GComment { get; init; }
    IGDelegateId<TValue> Id { get; init; }
  }
}


