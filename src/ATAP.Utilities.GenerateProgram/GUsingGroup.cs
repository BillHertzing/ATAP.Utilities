using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GUsingGroup : IGUsingGroup {
    public GUsingGroup(string gName = "", Dictionary<IPhilote<IGUsing>, IGUsing> gUsings = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GUsings = gUsings == default ? new Dictionary<IPhilote<IGUsing>, IGUsing>() : gUsings;
      Philote = new Philote<IGUsingGroup>();
    }

    public string GName { get; init; }
    public Dictionary<IPhilote<IGUsing>, IGUsing> GUsings { get; init; }
    public IPhilote<IGUsingGroup> Philote { get; init; }

  }
}
