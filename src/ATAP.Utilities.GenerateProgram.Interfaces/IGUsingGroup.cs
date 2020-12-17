using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGUsingGroup {
    string GName { get; init; }
    Dictionary<IPhilote<IGUsing>, IGUsing> GUsings { get; init; }
    IPhilote<IGUsingGroup> Philote { get; init; }
  }
}
