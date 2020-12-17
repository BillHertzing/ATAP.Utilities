using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGComment {
    IEnumerable<string> GStatements { get; init; }
    IPhilote<IGComment> Philote { get; init; }
  }
}
