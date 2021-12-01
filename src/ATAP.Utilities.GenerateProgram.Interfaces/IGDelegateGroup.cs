using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGDelegateGroup {
    string GName { get; init; }
    Dictionary<IPhilote<IGDelegate>, IGDelegate>? GDelegates { get; init; }
    IPhilote<IGDelegateGroup> Philote { get; init; }
  }
}
