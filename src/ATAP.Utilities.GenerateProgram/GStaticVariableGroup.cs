using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GStaticVariableGroup {
    public GStaticVariableGroup(string gName = default, Dictionary<Philote<GStaticVariable>, GStaticVariable> gStaticVariables = default) {
      GName = gName == default ? "" : gName;
      GStaticVariables = gStaticVariables == default ? new Dictionary<Philote<GStaticVariable>, GStaticVariable>() : gStaticVariables;
      Philote = new Philote<GStaticVariableGroup>();
    }

    public string GName { get; }
    public Dictionary<Philote<GStaticVariable>, GStaticVariable> GStaticVariables { get; }
    public Philote<GStaticVariableGroup> Philote { get; }
  }
}
