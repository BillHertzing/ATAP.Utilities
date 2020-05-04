using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GMethodBody {
    public GMethodBody(List<string>? statementList = default) {
      StatementList = statementList == default ? new List<string>() : statementList;
      Philote = new Philote<GMethodBody>();
    }
    public List<string>? StatementList { get; }
    public  Philote<GMethodBody> Philote { get; }

  }
}
