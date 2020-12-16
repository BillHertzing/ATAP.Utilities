using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GDelegateGroup {
    public GDelegateGroup(string gName, Dictionary<Philote<GDelegate>, GDelegate>? gDelegates = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GDelegates = gDelegates == default ? new Dictionary<Philote<GDelegate>, GDelegate>() : gDelegates;
      Philote = new Philote<GDelegateGroup>();
    }

    public string GName { get; }
    public Dictionary<Philote<GDelegate>, GDelegate>? GDelegates { get; }
    public  Philote<GDelegateGroup> Philote { get; }
  }
}
