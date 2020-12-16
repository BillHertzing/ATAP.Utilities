using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderConstStringGroupStringBuilder(this StringBuilder sb, GConstStringGroup gConstStringGroup, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}#region {gConstStringGroup.GName}{eol}");
      foreach (var kvp in gConstStringGroup.GConstStrings) {
        sb.RConstStringStringBuilder(kvp.Value, indent, eol, ct);
      }
      sb.Append($"{indent}#endregion {eol}");

      return sb;
    }
    public static IR1Top RConstStringGroup(this IR1Top r1Top, GConstStringGroup gConstStringGroup) {
      r1Top.Indent.Append(r1Top.IndentDelta);
      r1Top.Sb.RenderConstStringGroupStringBuilder(gConstStringGroup, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      return r1Top;
    }
    public static IR1Top RConstStringGroup(this IR1Top r1Top, List<GConstStringGroup> gConstStringGroups) {
      foreach (var o in gConstStringGroups) {
        r1Top.RConstStringGroup(o);
      }
      return r1Top;
    }
    public static IR1Top RConstStringGroup(this IR1Top r1Top, Dictionary<Philote<GConstStringGroup>, GConstStringGroup> gConstStringGroups) {
      foreach (var o in gConstStringGroups) {
        r1Top.RConstStringGroup(o.Value);
      }
      return r1Top;
    }
  }
}
