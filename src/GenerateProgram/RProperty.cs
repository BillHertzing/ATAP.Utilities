using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderPropertyStringBuilder(this StringBuilder sb, GProperty gProperty, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{indent}{gProperty.GVisibility} {gProperty.GType} {gProperty.GName} {gProperty.GAccessors}{eol}");
    }
    public static IR1Top RProperty(this IR1Top r1Top, GProperty gProperty) {
      r1Top.Sb.RenderPropertyStringBuilder(gProperty, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      return r1Top;
    }
    public static IR1Top RProperty(this IR1Top r1Top, List<GProperty> gPropertys) {
      foreach (var o in gPropertys) {
        r1Top.RProperty(o);
      }
      return r1Top;
    }
    public static IR1Top RProperty(this IR1Top r1Top, Dictionary<Philote<GProperty>, GProperty> gPropertys) {
      foreach (var kvp in gPropertys) {
        r1Top.RProperty(kvp.Value);
      }
      return r1Top;
    }
  }
}
