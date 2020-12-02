using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GProperty {
    public GProperty(string gName = default, string gType = default, string gAccessors = "{ get; set; }", string? gVisibility = default) {
      GName = gName == default ? "" : gName;
      GType = gType == default ? "" : gType;
      GAccessors = gAccessors ?? throw new ArgumentNullException(nameof(gAccessors));
      GVisibility = gVisibility == default ? "" : gVisibility;
      Philote = new Philote<GProperty>();
    }

    public string GName { get;  }
    public string GType { get;  }
    public string GAccessors { get;  }
    public string? GVisibility { get;  }
    public Philote<GProperty> Philote { get; }

  }
}

