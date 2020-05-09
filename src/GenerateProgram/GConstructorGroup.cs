using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GConstructorGroup :GMethodGroup {
    public GConstructorGroup(string gName, Dictionary<Philote<GDelegate>, GDelegate> gConstructors) :base (gName){
      GConstructors = gConstructors ?? throw new ArgumentNullException(nameof(gConstructors));
      Philote = new Philote<GConstructorGroup>();
    }

    public Dictionary<Philote<GDelegate>, GDelegate> GConstructors { get; }
    public new Philote<GConstructorGroup> Philote { get; }
  }
}

