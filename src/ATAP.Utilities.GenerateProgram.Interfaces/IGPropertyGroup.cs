using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGPropertyGroupId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGPropertyGroup<TValue> where TValue : notnull {
    string GName { get; }
    IDictionary<IGPropertyId<TValue>, IGProperty<TValue>> GPropertys { get; init; }
    IGPropertyGroupId<TValue> Id { get; init; }
  }
}



