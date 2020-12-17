using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GResourceItem : IGResourceItem {
    public GResourceItem(string gName, string gValue, string? gComment = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GValue = gValue ?? throw new ArgumentNullException(nameof(gValue));
      GComment = gComment == default ? "" : gComment;
      Philote = new Philote<GResourceItem>();
    }

    public string GName { get; init; }
    public string GValue { get; init; }
    public string? GComment { get; init; }
    public IPhilote<IGResourceItem> Philote { get; init; }
  }
}
