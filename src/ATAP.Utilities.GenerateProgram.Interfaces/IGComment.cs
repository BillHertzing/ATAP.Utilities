using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGCommentId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGComment<TValue> where TValue : notnull {
    IEnumerable<string> GStatements { get; init; }
    IGCommentId<TValue> Id { get; init; }
  }
}


