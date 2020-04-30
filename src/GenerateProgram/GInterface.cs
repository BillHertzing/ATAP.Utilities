using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GInterface {
    public GInterface(string gName, Dictionary<Philote<GProperty>, GProperty> gPropertys = default, Dictionary<Philote<GMethod>, GMethod> gMethods= default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      if (gPropertys == default) {
        GPropertys = new Dictionary<Philote<GProperty>, GProperty>();}
      else {
        GPropertys = gPropertys;
      }
      if (gMethods == default) {
        GMethods = new Dictionary<Philote<GMethod>, GMethod>();}
      else {
        GMethods = gMethods;
      }
      Philote = new Philote<GInterface>();
    }
    public string GName { get; }
    public Dictionary<Philote<GProperty>, GProperty> GPropertys { get; }
    public Dictionary<Philote<GMethod>, GMethod> GMethods { get; }
    public Philote<GInterface> Philote { get; }
  }
}

