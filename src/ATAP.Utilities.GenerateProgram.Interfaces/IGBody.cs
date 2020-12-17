using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGBody {
    IList<string> GStatements { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGBody> Philote { get; init; }
  }
}
