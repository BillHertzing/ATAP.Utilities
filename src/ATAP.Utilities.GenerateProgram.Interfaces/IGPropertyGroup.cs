using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGPropertyGroup {
    string GName { get; }
    IDictionary<IPhilote<IGProperty>, IGProperty> GPropertys { get; init; }
    IPhilote<IGPropertyGroup> Philote { get; init; }
  }
}

