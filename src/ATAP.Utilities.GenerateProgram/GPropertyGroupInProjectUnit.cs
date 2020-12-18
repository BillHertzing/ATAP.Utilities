using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public record GPropertyGroupInProjectUnit : IGPropertyGroupInProjectUnit {
    public GPropertyGroupInProjectUnit(string? gName = default, string? gDescription = default, IList<String>? gPropertyGroupStatements = default) {
      GName = gName == default ? "" : gName;
      GDescription = gDescription == default ? "" : gDescription;
      GPropertyGroupStatements = gPropertyGroupStatements == default ? new List<String>() : gPropertyGroupStatements;
      Philote = new Philote<IGPropertyGroupInProjectUnit>();
    }
    public string? GName { get; init; }
    public string? GDescription { get; init; }
    public IList<String>? GPropertyGroupStatements { get; init; }
    public IPhilote<IGPropertyGroupInProjectUnit> Philote { get; init; }

  }
}
