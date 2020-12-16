using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GPropertyGroupInProjectUnit {
    public GPropertyGroupInProjectUnit(string? gName = default, string? gDescription = default, List<String>? gPropertyGroupStatements = default) {
      GName = gName == default ? "" : gName;
      GDescription = gDescription == default ? "" : gDescription;
      GPropertyGroupStatements = gPropertyGroupStatements == default ? new List<String>() : gPropertyGroupStatements;
      Philote = new Philote<GPropertyGroupInProjectUnit>();
    }
    public string? GName { get; }
    public string? GDescription { get; }
    public List<String>? GPropertyGroupStatements { get; }
    public Philote<GPropertyGroupInProjectUnit> Philote { get; }

  }
}
