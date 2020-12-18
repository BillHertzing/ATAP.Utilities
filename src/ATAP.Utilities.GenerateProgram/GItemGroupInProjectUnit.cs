using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public class GItemGroupInProjectUnit : IGItemGroupInProjectUnit {
    public GItemGroupInProjectUnit(string gName = "", string gDescription = "", IGBody gBody = default, IGComment gComment = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GDescription = gDescription == default ? "" : gDescription;
      GBody = gBody == default ? new GBody() : gBody;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<IGItemGroupInProjectUnit>();
    }
    public string GName { get; init; }
    public string GDescription { get; init; }
    public IGBody GBody { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGItemGroupInProjectUnit> Philote { get; init; }

  }
}
