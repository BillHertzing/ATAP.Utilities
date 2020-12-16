using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GUsing {
    public GUsing(string gName) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      Philote = new Philote<GUsing>();
    }

    public string GName { get; }
    public Philote<GUsing> Philote { get; }
  }
}
