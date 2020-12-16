using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GConstStringGroup {
    public GConstStringGroup(string gName = "", Dictionary<Philote<GConstString>, GConstString> gConstStrings = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GConstStrings = gConstStrings == default ? new Dictionary<Philote<GConstString>, GConstString>() : gConstStrings;
      Philote = new Philote<GConstStringGroup>();
    }
    public string GName { get; }
    public Dictionary<Philote<GConstString>, GConstString> GConstStrings { get; }
    public Philote<GConstStringGroup> Philote { get; }

  }
}
