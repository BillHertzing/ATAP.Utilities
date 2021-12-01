using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGItemGroupInProjectUnitId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGItemGroupInProjectUnit<TValue> where TValue : notnull {
    string GName { get; init; }
    string GDescription { get; init; }
    IGBody GBody { get; init; }
    IGComment GComment { get; init; }
    IGItemGroupInProjectUnitId<TValue> Id { get; init; }
  }
}


