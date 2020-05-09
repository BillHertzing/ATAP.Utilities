using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GBody :GStatementList {
    public GBody(List<string> gStatementsList = default) : base(gStatementsList) {
    }
    public GBody(GStatementList gStatementsList = default) : base(gStatementsList.GStatements) {
    }
  }
}
