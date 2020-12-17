using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
 
  public class GBody : IGBody {
    public GBody(IList<string> gStatements = default, IGComment gComment = default
    ) {
      GStatements = gStatements == default ? new List<string>() : gStatements;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<GBody>();
    }
    public IList<string> GStatements { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGBody> Philote { get; init; }
  }
}
