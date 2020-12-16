using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GItemGroupInProjectUnit {
    public GItemGroupInProjectUnit(string gName = "", string gDescription = "", GBody gBody = default, GComment gComment = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GDescription = gDescription == default ? "" : gDescription;
      GBody = gBody == default? new GBody() : gBody;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GItemGroupInProjectUnit>();
    }
    public string GName { get; }
    public string GDescription { get; }
    public GBody GBody { get; }
    public GComment GComment { get; }
    public Philote<GItemGroupInProjectUnit> Philote { get; }

  }
}
