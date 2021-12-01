using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGMethodGroup {
    string GName { get; init; }
    IDictionary<IPhilote<IGMethod>, IGMethod>? GMethods { get; init; }
    IPhilote<IGMethodGroup> Philote { get; init; }
  }
}

