using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  

  public class GPropertiesUnit : IGPropertiesUnit {
    public GPropertiesUnit(string gName, string gRelativePath = default, string gFileSuffix = default
    //Dictionary<Philote<GUsing>, GUsing> gUsings = default
    ) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GRelativePath = gRelativePath == default ? "Properties/" : gRelativePath;
      GFileSuffix = gFileSuffix == default ? ".cs" : gFileSuffix;
      //GUsings = gUsings == default ? new Dictionary<Philote<GUsing>, GUsing>() : gUsings;
      Philote = new Philote<GPropertiesUnit>();
    }

    public string GName { get; init; }
    public string GRelativePath { get; init; }
    public string GFileSuffix { get; init; }
    public IPhilote<IGPropertiesUnit> Philote { get; init; }
  }
}

