using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GConstStringGroup : IGConstStringGroup {
    public GConstStringGroup(string gName = "", IDictionary<IPhilote<IGConstString>, IGConstString> gConstStrings = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GConstStrings = gConstStrings == default ? new Dictionary<IPhilote<IGConstString>, IGConstString>() : gConstStrings;
      Philote = new Philote<IGConstStringGroup>();
    }
    public string GName { get; init; }
    public IDictionary<IPhilote<IGConstString>, IGConstString> GConstStrings { get; init; }
    public IPhilote<IGConstStringGroup> Philote { get; init; }

  }
}
