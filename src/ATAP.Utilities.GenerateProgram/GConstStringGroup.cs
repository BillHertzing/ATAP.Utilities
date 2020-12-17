using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GConstStringGroup : IGConstStringGroup {
    public GConstStringGroup(string gName = "", IDictionary<IPhilote<IGConstString>, IGConstString> gConstStrings = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GConstStrings = gConstStrings == default ? new Dictionary<Philote<GConstString>, GConstString>() : gConstStrings;
      Philote = new Philote<GConstStringGroup>();
    }
    public string GName { get; init; }
    public IDictionary<IPhilote<IGConstString>, IGConstString> GConstStrings { get; init; }
    public IPhilote<IGConstStringGroup> Philote { get; init; }

  }
}
