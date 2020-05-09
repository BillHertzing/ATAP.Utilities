using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GEnumerationGroup {
    public GEnumerationGroup(string gName = default, Dictionary<Philote<GEnumeration>, GEnumeration> gEnumerations = default) {
      GName = gName == default ? "" : gName;
      GEnumerations = gEnumerations == default ? new Dictionary<Philote<GEnumeration>, GEnumeration>() : gEnumerations;
      Philote = new Philote<GEnumerationGroup>();
    }

    public string GName { get; }
    public Dictionary<Philote<GEnumeration>, GEnumeration> GEnumerations { get; }
    public  Philote<GEnumerationGroup> Philote { get; }
  }
}
