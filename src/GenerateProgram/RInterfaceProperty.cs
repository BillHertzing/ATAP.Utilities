using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderInterfacePropertyStringBuilder(this StringBuilder sb, GProperty gProperty, StringBuilder indent, string eol, CancellationToken? ct = default) {
      return sb.Append($"{indent}{gProperty.GType} {gProperty.GName} {gProperty.GAccessors}{eol}");
    }

    public static IR1Top RInterfaceProperty(this IR1Top r1Top, GProperty gProperty) {
      r1Top.Sb.RenderInterfacePropertyStringBuilder(gProperty, r1Top.R1TopData.Indent, r1Top.R1TopData.Eol, r1Top.R1TopData.Ct);
      return r1Top;
    }

    public static IR1Top RInterfaceProperty(this IR1Top r1Top, List<GProperty> gPropertys) {
      foreach (var o in gPropertys) {
        r1Top.RInterfaceProperty(o);
      }
      return r1Top;
    }
    public static IR1Top RInterfaceProperty(this IR1Top r1Top, Dictionary<Philote<GProperty>, GProperty> gPropertys) {
      foreach (var kvp in gPropertys) {
        r1Top.RInterfaceProperty(kvp.Value);
      }
      return r1Top;
    }
  }
}
