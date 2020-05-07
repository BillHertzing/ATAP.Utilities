using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GComment :GStatementList {
    public GComment(List<string>? statementList = default) :base(statementList) {
      Philote = new Philote<GComment>();
    }
    public new Philote<GComment> Philote { get; }
  }
}
