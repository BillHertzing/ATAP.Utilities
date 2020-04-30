using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GUsingGroup {
    public GUsingGroup(string gName, Dictionary<Philote<GUsing>, GUsing> gUsings = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      if (gUsings == default) {
        GUsings = new Dictionary<Philote<GUsing>, GUsing>();
      }
      else {
        GUsings = gUsings;
      }
      Philote = new Philote<GUsingGroup>();
    }
    public string GName { get; }
    public Dictionary<Philote<GUsing>, GUsing> GUsings { get; }
    public Philote<GUsingGroup> Philote { get; }

  }
}
