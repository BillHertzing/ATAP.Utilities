using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGItemGroupInProjectUnitId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGItemGroupInProjectUnit<TValue> where TValue : notnull {
  //   string GName { get; init; }
  //   string GDescription { get; init; }
  //   IGBody<TValue> GBody { get; init; }
  //   IGComment<TValue>? GComment { get; init; }
  //   IGItemGroupInProjectUnitId<TValue> Id { get; init; }
  }
}


