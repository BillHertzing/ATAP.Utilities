using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GStatementList {
    public GStatementList(List<string>? gStatements = default) {
      GStatements = gStatements == default ? new List<string>() : gStatements;
      Philote = new Philote<GStatementList>();
    }

    public List<string>? GStatements { get; }
    public Philote<GStatementList> Philote { get; }

  }
}
