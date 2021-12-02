using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGDelegateGroupId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGDelegateGroup<TValue> where TValue : notnull {
    string GName { get; init; }
    Dictionary<IGDelegateId<TValue>, IGDelegate<TValue>>? GDelegates { get; init; }
    IGDelegateGroupId<TValue> Id { get; init; }
  }
}


