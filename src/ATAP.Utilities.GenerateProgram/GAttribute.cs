using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GAttribute {
    public GAttribute(string gName = "", string gValue ="",
      GComment gComment = default
      ) {
      GName = gName ;
      GValue = gValue ;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GAttribute>();
    }

    public string GName { get; }
    public string GValue { get; }
    public GComment GComment { get; }
    public Philote<GAttribute> Philote { get; }
  }
}
