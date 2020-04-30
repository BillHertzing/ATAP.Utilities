using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GProperty {
    public GProperty(string gName, string gType = default, string gAccessors = "{ get; set }", string? gVisibility = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GType = gType == default ? gName : gType;
      GAccessors = gAccessors ?? throw new ArgumentNullException(nameof(gAccessors));
      GVisibility = gVisibility;
      Philote = new Philote<GProperty>();
    }

    public string GName { get; set; }
    public string GType { get; set; }
    public string GAccessors { get; set; }
    public string? GVisibility { get; set; }
    public Philote<GProperty> Philote { get; }

  }
}

