using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GResourceUnit {
    public GResourceUnit(string gName, string gRelativePath=default, string gFileSuffix=default,
      Dictionary<Philote<GResourceItem>, GResourceItem> gResourceItems = default
    ){
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GRelativePath = gRelativePath == default ? "Resources" : gRelativePath;
      GFileSuffix = gFileSuffix == default ? ".resx" : gFileSuffix;
      GResourceItems = gResourceItems == default ? new Dictionary<Philote<GResourceItem>, GResourceItem>() : gResourceItems;
      Philote = new Philote<GResourceUnit>();
    }

    public string GName { get; }
    public string GRelativePath { get; }
    public string GFileSuffix { get; }
    public Dictionary<Philote<GResourceItem>, GResourceItem> GResourceItems{ get; }
    public Philote<GResourceUnit> Philote { get; }
    public static string Header { get; } = StringConstants.HeaderTextStringDefault;
  }
}

