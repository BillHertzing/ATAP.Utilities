using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderResourceItemStringBuilder(this StringBuilder sb, GResourceItem gResourceItem, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"<data name=\"{gResourceItem.GName}\" xml:space=\"preserve\">{eol}");
      sb.Append($"<value>{gResourceItem.GValue}</value>{eol}");
      return sb.Append($"</data>{eol}");
    }
    public static IR1Top RResourceUnit(this IR1Top r1Top,GResourceUnit gResourceUnit, IW1Top w1Top) {
      r1Top.R1TopData.Ct?.ThrowIfCancellationRequested();
      StringBuilder localStringBuilder = new StringBuilder();
      try {
        localStringBuilder.FetchFileAsStringBuilder("CResourceUnitPreambleTemplate.xml");
      }
      catch (Exception e) {
        Console.WriteLine(e);  // ToDo: better exception handling
        throw;
      }
      if (gResourceUnit.GResourceItems.Any()) {
        foreach (var kvp in gResourceUnit.GResourceItems) {
          localStringBuilder.RenderResourceItemStringBuilder(kvp.Value,  r1Top.R1TopData.Eol, r1Top.R1TopData.Ct);
        }
      }
      w1Top.WResourceUnit(gResourceUnit, r1Top.Sb);
      return r1Top;
    }
    public static IR1Top RResourceUnit(this IR1Top r1Top, List<GResourceUnit> gResourceUnits,IW1Top w1Top) {
      foreach (var o in gResourceUnits) {
        r1Top.RResourceUnit(o, w1Top);
      }
      return r1Top;
    }

    public static IR1Top RResourceUnit(this IR1Top r1Top, Dictionary<Philote<GResourceUnit>, GResourceUnit> gResourceUnits,IW1Top w1Top) {
      foreach (var kvp in gResourceUnits) {
        r1Top.RResourceUnit(kvp.Value, w1Top);
      }
      return r1Top;
    }
  }
}
