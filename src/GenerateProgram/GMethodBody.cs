using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GMethodBody :GStatementList {
    public GMethodBody(List<string> gStatementsList = default) : base(gStatementsList) {
    }
    public GMethodBody(GStatementList gStatementsList = default) : base(gStatementsList.GStatements) {
    }
  }
}
