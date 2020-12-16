using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GBody {
    public GBody( List<string> gStatements = default, GComment gComment = default
    ) {
      GStatements = gStatements == default ? new List<string>() : gStatements;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<GBody>();
    }
    public List<string> GStatements { get; }
    public GComment GComment { get; }
    public Philote<GBody> Philote { get; }
  }
}
