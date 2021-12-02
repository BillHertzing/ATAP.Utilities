using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGUsingGroupId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGUsingGroup<TValue> where TValue : notnull {
    string GName { get; init; }
    Dictionary<IGUsingId<TValue>, IGUsing<TValue>> GUsings { get; init; }
    IGUsingGroupId<TValue> Id { get; init; }
  }
}



