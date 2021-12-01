using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram
{
  

  public interface IGArgumentId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGArgument<TValue> where TValue : notnull {
    string GName { get; init; }
    string GType { get; init; }
    bool IsRef { get; init; }
    bool IsOut { get; init; }
    IGArgumentId<TValue> Id { get; init; }
  }
}


