using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGConstStringGroup {
    string GName { get; init; }
    IDictionary<IPhilote<IGConstString>, IGConstString> GConstStrings { get; init; }
    IPhilote<IGConstStringGroup> Philote { get; init; }
  }
}
