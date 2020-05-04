using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GComment :GStatementList {
    public GComment(List<string>? statementList = default) :base(statementList) {
//      StatementList = statementList == default ? new List<string>() : statementList;
      Philote = new Philote<GComment>();
    }

    //public List<string>? StatementList { get; }
    public new Philote<GComment> Philote { get; }

  }
}
