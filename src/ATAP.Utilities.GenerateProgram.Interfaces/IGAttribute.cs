using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGAttributeId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGAttribute<TValue> where TValue : notnull {
    string GName { get; init; }
    string GValue { get; init; }
    IGComment GComment { get; init; }
    IGAttributeId<TValue> Id { get; init; }
  }
}


