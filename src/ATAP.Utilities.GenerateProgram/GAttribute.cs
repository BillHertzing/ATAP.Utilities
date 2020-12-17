using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  
  public class GAttribute : IGAttribute {
    public GAttribute(string gName = "", string gValue = "",
      IGComment gComment = default
      ) {
      GName = gName;
      GValue = gValue;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<GAttribute>();
    }

    public string GName { get; init; }
    public string GValue { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGAttribute> Philote { get; init; }
  }
}
