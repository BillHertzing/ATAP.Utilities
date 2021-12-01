using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGPropertyId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGProperty<TValue> where TValue : notnull {
    string GName { get; }
    string GType { get; }
    string GAccessors { get; }
    string? GVisibility { get; }
    IGPropertyId<TValue> Id { get; init; }
  }
}


