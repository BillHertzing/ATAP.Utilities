using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GMethodGroup : IGMethodGroup {
    public GMethodGroup(string gName, Dictionary<IPhilote<IGMethod>, IGMethod>? gMethods = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GMethods = gMethods == default ? new Dictionary<Philote<GMethod>, GMethod>() : gMethods;
      Philote = new Philote<GMethodGroup>();
    }

    public string GName { get; init; }
    public Dictionary<IPhilote<IGMethod>, IGMethod>? GMethods { get; init; }
    public IPhilote<IGMethodGroup> Philote { get; init; }
  }
}
