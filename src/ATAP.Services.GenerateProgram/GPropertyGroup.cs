using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GPropertyGroup {
    public GPropertyGroup(string gName, Dictionary<Philote<GProperty>, GProperty> gPropertys = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      if (gPropertys == default) {
        GPropertys = new Dictionary<Philote<GProperty>, GProperty>();
      }
      else {
        GPropertys = gPropertys;
      }
      Philote = new Philote<GPropertyGroup>();
    }

    public string GName { get;  }
    public Dictionary<Philote<GProperty>, GProperty> GPropertys { get; }
    public Philote<GPropertyGroup> Philote { get; }

  }
}
