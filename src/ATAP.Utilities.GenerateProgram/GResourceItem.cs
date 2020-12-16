using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GResourceItem {
    public GResourceItem(string gName, string gValue, string? gComment = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GValue = gValue ?? throw new ArgumentNullException(nameof(gValue));
      GComment = gComment == default? "": gComment;
      Philote = new Philote<GResourceItem>();
    }

    public string GName { get; }
    public string GValue { get; }
    public string? GComment { get; }
    public Philote<GResourceItem> Philote { get; }
  }
}
