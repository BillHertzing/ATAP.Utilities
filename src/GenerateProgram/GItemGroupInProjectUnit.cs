using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GItemGroupInProjectUnit {
    public GItemGroupInProjectUnit(string gName = "", string? gDescription = default, List<String> gItemGroupStatements = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GDescription = gDescription == default ? "" : gDescription;

      GItemGroupStatements = gItemGroupStatements  == default? new List<String> () : gItemGroupStatements;
      Philote = new Philote<GItemGroupInProjectUnit>();
    }
    public string GName { get; }
    public string GDescription { get; }
    public List<String>  GItemGroupStatements { get; }
    public Philote<GItemGroupInProjectUnit> Philote { get; }

  }
}
