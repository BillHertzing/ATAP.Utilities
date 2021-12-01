using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGBodyId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGBody<TValue> where TValue : notnull {
    IList<string> GStatements { get; init; }
    IGComment GComment { get; init; }
    IGBodyId<TValue> Id { get; init; }

  }
}


