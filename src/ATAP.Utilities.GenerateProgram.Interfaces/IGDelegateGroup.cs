using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGDelegateGroup {
    string GName { get; init; }
    Dictionary<IPhilote<IGDelegate>, IGDelegate>? GDelegates { get; init; }
    IPhilote<IGDelegateGroup> Philote { get; init; }
  }
}