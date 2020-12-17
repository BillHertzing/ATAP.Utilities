using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGComment
  {
    List<string> GStatements { get; init; }
    IPhilote<IGComment> Philote { get; init; }
  }

  public record GComment : IGComment {
    public GComment(List<string> gStatements = default)  {
      GStatements = gStatements == default ? new List<string>() : gStatements;
      Philote = new Philote<GComment>();
    }

    public List<string> GStatements { get; init; }
    public IPhilote<IGComment> Philote { get; init; }
  }
}
