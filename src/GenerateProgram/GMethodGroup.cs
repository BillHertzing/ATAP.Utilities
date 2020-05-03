using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GMethodGroup {
    public GMethodGroup(string gName, Dictionary<Philote<GMethod>, GMethod>? gMethods = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GMethods = gMethods == default ? new Dictionary<Philote<GMethod>, GMethod>() : gMethods;
      Philote = new Philote<GMethodGroup>();
    }

    public string GName { get; }
    public Dictionary<Philote<GMethod>, GMethod>? GMethods { get; }
    public  Philote<GMethodGroup> Philote { get; }
  }
}
