using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGPropertyGroup {
    string GName { get; }
    IDictionary<IPhilote<IGProperty>, IGProperty> GPropertys { get; init; }
    IPhilote<IGPropertyGroup> Philote { get; init; }
  }
}
