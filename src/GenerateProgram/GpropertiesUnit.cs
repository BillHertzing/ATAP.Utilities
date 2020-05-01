using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GPropertiesUnit {
    public GPropertiesUnit(string gName, string gRelativePath=default, string gFileSuffix=default
      //Dictionary<Philote<GUsing>, GUsing> gUsings = default
    ){
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GRelativePath = gRelativePath == default ? "Properties/" : gRelativePath;
      GFileSuffix = gFileSuffix == default ? ".cs" : gFileSuffix;
      //GUsings = gUsings == default ? new Dictionary<Philote<GUsing>, GUsing>() : gUsings;
      Philote = new Philote<GPropertiesUnit>();
    }

    public string GName { get; }
    public string GRelativePath { get; }
    public string GFileSuffix { get; }
    //Dictionary<Philote<GUsing>, GUsing> gUsings = default,
    public Philote<GPropertiesUnit> Philote { get; }
  }
}

