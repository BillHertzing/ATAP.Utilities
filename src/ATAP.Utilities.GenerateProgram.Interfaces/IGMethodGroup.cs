using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGMethodGroupId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGMethodGroup<TValue> where TValue : notnull {
    string GName { get; init; }
    IDictionary<IGMethodId<TValue>, IGMethod<TValue>>? GMethods { get; init; }
    IGMethodGroupId<TValue> Id { get; init; }
  }
}



