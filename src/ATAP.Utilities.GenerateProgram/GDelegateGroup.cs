using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GDelegateGroup : IGDelegateGroup {
    public GDelegateGroup(string gName, Dictionary<IPhilote<IGDelegate>, IGDelegate>? gDelegates = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GDelegates = gDelegates == default ? new Dictionary<IPhilote<IGDelegate>, IGDelegate>() : gDelegates;
      Philote = new Philote<IGDelegateGroup>();
    }

    public string GName { get; init; }
    public Dictionary<IPhilote<IGDelegate>, IGDelegate>? GDelegates { get; init; }
    public IPhilote<IGDelegateGroup> Philote { get; init; }
  }
}
