using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram
{
  

  public interface IGUsingId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGUsing<TValue> where TValue : notnull {
    string GName { get; init; }
    IGUsingId<TValue> Id { get; init; }
  }
}


