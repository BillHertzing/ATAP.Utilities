using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGResourceItemId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGResourceItem<TValue> where TValue : notnull {
    string GName { get; init; }
    string GValue { get; init; }
    string? GComment { get; init; }
    IGResourceItemId<TValue> Id { get; init; }
  }
}


