using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGConstStringId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGConstString<TValue> where TValue : notnull {
    string GName { get; init; }
    string GValue { get; init; }
    IGConstStringId<TValue> Id { get; init; }
  }
}


