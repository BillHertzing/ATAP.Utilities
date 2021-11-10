using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGBody<TValue> where TValue : notnull {
    IList<string> GStatements { get; init; }
    IGComment GComment { get; init; }
    IAbstractPhilote<IGBody<TValue>, TValue>   Philote { get; init; }

  }
}
