using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GMethodGroup : IGMethodGroup {
    public GMethodGroup(string gName, IDictionary<IPhilote<IGMethod>, IGMethod>? gMethods = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GMethods = gMethods == default ? new Dictionary<IPhilote<IGMethod>, IGMethod>() : gMethods;
      Philote = new Philote<IGMethodGroup>();
    }

    public string GName { get; init; }
    public IDictionary<IPhilote<IGMethod>, IGMethod>? GMethods { get; init; }
    public IPhilote<IGMethodGroup> Philote { get; init; }
  }
}
