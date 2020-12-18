using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RResourceItemStringBuilder(this StringBuilder sb, IGResourceItem gResourceItem, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"<data name=\"{gResourceItem.GName}\" xml:space=\"preserve\">{eol}<value>{gResourceItem.GValue}</value>{eol}</data>{eol}{eol}");
      //sb.Append($"<value>{gResourceItem.GValue}</value>{eol}</data>{eol}{eol}");
      //return sb.Append($"</data>{eol}{eol}");
    }
    public static IR1Top RResourceUnit(this IR1Top r1Top, IGResourceUnit gResourceUnit, IW1Top w1Top) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      StringBuilder localStringBuilder = new StringBuilder();
      try {
        localStringBuilder.FetchFileAsStringBuilder("CResourceUnitPreambleTemplate.xml");
      }
      catch (Exception e) {
        Console.WriteLine(e);  // ToDo: better exception handling
        throw;
      }
 
      // ToDo: Figure out how to insert the header into the XML File Fetched as a template
      if (gResourceUnit.GResourceItems.Any()) {
        foreach (var kvp in gResourceUnit.GResourceItems) {
          localStringBuilder.RResourceItemStringBuilder(kvp.Value,  r1Top.Eol, r1Top.Ct);
        }
      }

      localStringBuilder.Append($"</root>{r1Top.Eol}");
      r1Top.Sb.Append(localStringBuilder);
      w1Top.WResourceUnit(gResourceUnit, r1Top.Sb);
      r1Top.Sb.Clear();
      return r1Top;
    }
    public static IR1Top RResourceUnit(this IR1Top r1Top, List<IGResourceUnit> gResourceUnits,IW1Top w1Top) {
      foreach (var o in gResourceUnits) {
        r1Top.RResourceUnit(o, w1Top);
      }
      return r1Top;
    }

    public static IR1Top RResourceUnit(this IR1Top r1Top, IDictionary<IPhilote<IGResourceUnit>, IGResourceUnit> gResourceUnits, IW1Top w1Top) {
      foreach (var kvp in gResourceUnits) {
        r1Top.RResourceUnit(kvp.Value, w1Top);
      }
      return r1Top;
    }
  }
}
