using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GArgument {
    public GArgument(string gName, string gType, bool isRef = false, bool isOut = false) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GType = gType ?? throw new ArgumentNullException(nameof(gType));
      IsRef = isRef;
      IsOut = isOut;
      Philote = new Philote<GArgument>();

    }

    public string GName { get; }
    public string GType { get; }
    public bool IsRef { get; }
    public bool IsOut { get; }
    public Philote<GArgument> Philote { get; }


  }
}
