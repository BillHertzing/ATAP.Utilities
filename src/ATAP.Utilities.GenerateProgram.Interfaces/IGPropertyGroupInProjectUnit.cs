using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGPropertyGroupInProjectUnitId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGPropertyGroupInProjectUnit<TValue> where TValue : notnull {
    string? GName { get; init; }
    string? GDescription { get; init; }
    IList<string>? GPropertyGroupStatements { get; init; }
    IGPropertyGroupInProjectUnitId<TValue> Id { get; init; }
  }
}


