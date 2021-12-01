using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGPropertiesUnitId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGPropertiesUnit<TValue> where TValue : notnull {
    string GName { get; init; }
    string GRelativePath { get; init; }
    string GFileSuffix { get; init; }
    IGPropertiesUnitId<TValue> Id { get; init; }
  }
}


