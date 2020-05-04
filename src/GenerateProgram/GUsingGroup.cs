using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GUsingGroup {
    public GUsingGroup(string gName = "", Dictionary<Philote<GUsing>, GUsing> gUsings = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GUsings = gUsings == default ? new Dictionary<Philote<GUsing>, GUsing>() : gUsings;
      Philote = new Philote<GUsingGroup>();
    }

    public string GName { get; }
    public Dictionary<Philote<GUsing>, GUsing> GUsings { get; }
    public Philote<GUsingGroup> Philote { get; }

  }
}
