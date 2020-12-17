using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public record GArgument : IGArgument {
    public GArgument(string gName, string gType, bool isRef = false, bool isOut = false) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GType = gType ?? throw new ArgumentNullException(nameof(gType));
      IsRef = isRef;
      IsOut = isOut;
      Philote = new Philote<GArgument>();

    }

    public string GName { get; init;}
    public string GType { get; init; }
    public bool IsRef { get; init; }
    public bool IsOut { get; init; }
    public Philote<GArgument> Philote { get; init; }


  }
}

