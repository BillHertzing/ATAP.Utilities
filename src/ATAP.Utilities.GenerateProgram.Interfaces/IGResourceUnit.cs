using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGResourceUnit {
    string GName { get; init; }
    string GRelativePath { get; init; }
    string GFileSuffix { get; init; }
    Dictionary<IPhilote<IGResourceItem>, IGResourceItem> GResourceItems { get; init; }
    IGPatternReplacement GPatternReplacement { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGResourceUnit> Philote { get; init; }
  }
}

