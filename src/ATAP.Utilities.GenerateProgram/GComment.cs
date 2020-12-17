using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GComment : IGComment {
    public GComment(IEnumerable<string> gStatements = default)  {
      GStatements = gStatements == default ? new List<string>() : gStatements;
      Philote = new Philote<IGComment>();
    }

    public IEnumerable<string> GStatements { get; init; }
    public IPhilote<IGComment> Philote { get; init; }
  }
}
