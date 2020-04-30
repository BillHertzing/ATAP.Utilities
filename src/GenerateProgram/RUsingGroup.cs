using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderUsingGroupStringBuilder(this StringBuilder sb, GUsingGroup gUsingGroup, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      foreach (var kvp in gUsingGroup.GUsings) {
        sb.RenderUsingStringBuilder(kvp.Value, indent, eol, ct);
      }

      return sb;
    }
    public static IR1Top RUsingGroup(this IR1Top r1Top, GUsingGroup gUsingGroup) {
      r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#region {gUsingGroup.GName}{r1Top.R1TopData.Eol}");
      r1Top.R1TopData.Indent.Append(r1Top.R1TopData.IndentDelta);
      r1Top.Sb.RenderUsingGroupStringBuilder(gUsingGroup, r1Top.R1TopData.Indent, r1Top.R1TopData.Eol, r1Top.R1TopData.Ct);
      r1Top.R1TopData.Indent.ReplaceFirst(r1Top.R1TopData.IndentDelta, "");
      r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#endregion {r1Top.R1TopData.Eol}");
      return r1Top;
    }
    public static IR1Top RUsingGroup(this IR1Top r1Top, List<GUsingGroup> gUsingGroups) {
      foreach (var o in gUsingGroups) {
        r1Top.RUsingGroup(o);
      }
      return r1Top;
    }
    public static IR1Top RUsingGroup(this IR1Top r1Top, Dictionary<Philote<GUsingGroup>, GUsingGroup> gUsingGroups) {
      foreach (var o in gUsingGroups) {
        r1Top.RUsingGroup(o.Value);
      }
      return r1Top;
    }
  }
}
