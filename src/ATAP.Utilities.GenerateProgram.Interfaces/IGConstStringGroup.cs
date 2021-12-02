using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGConstStringGroupId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGConstStringGroup<TValue> where TValue : notnull {
    string GName { get; init; }
    IDictionary<IGConstStringId<TValue>, IGConstString<TValue>> GConstStrings { get; init; }
    IGConstStringGroupId<TValue> Id { get; init; }
  }
}



