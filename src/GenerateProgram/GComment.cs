using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GComment  {
    public GComment(List<string> gStatements = default)  {
      GStatements = gStatements == default ? new List<string>() : gStatements;
      Philote = new Philote<GComment>();
    }
    
    public List<string> GStatements { get; }
    public new Philote<GComment> Philote { get; }
  }
}
