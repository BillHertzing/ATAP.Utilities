using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGMethodGroup {
    string GName { get; init; }
    Dictionary<IPhilote<IGMethod>, IGMethod>? GMethods { get; init; }
    IPhilote<IGMethodGroup> Philote { get; init; }
  }
}
