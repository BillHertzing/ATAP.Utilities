using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GConstString {
    public GConstString(string gName, string gValue) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GValue = gValue ?? throw new ArgumentNullException(nameof(gValue));
      Philote = new Philote<GConstString>();
    }

    public string GName { get; }
    public string GValue { get; }
    public Philote<GConstString> Philote { get; }
  }
}
