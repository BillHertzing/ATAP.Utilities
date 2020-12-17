using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGPropertyGroupInProjectUnit {
    string? GName { get; init; }
    string? GDescription { get; init; }
    IList<string>? GPropertyGroupStatements { get; init; }
    IPhilote<IGPropertyGroupInProjectUnit> Philote { get; init; }
  }
}
