using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderUsingGroupStringBuilder(this StringBuilder sb, IGUsingGroup gUsingGroup, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      foreach (var kvp in gUsingGroup.GUsings) {
        sb.RenderUsingStringBuilder(kvp.Value, indent, eol, ct);
      }

      return sb;
    }
    public static IR1Top RUsingGroup(this IR1Top r1Top, IGUsingGroup gUsingGroup) {
      r1Top.Sb.Append($"{r1Top.Indent}#region {gUsingGroup.GName}{r1Top.Eol}");
      r1Top.Indent.Append(r1Top.IndentDelta);
      r1Top.Sb.RenderUsingGroupStringBuilder(gUsingGroup, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.Append($"{r1Top.Indent}#endregion {r1Top.Eol}");
      return r1Top;
    }
    public static IR1Top RUsingGroup(this IR1Top r1Top, IEnumerable<IGUsingGroup> gUsingGroups) {
      foreach (var o in gUsingGroups) {
        r1Top.RUsingGroup(o);
      }
      return r1Top;
    }
    public static IR1Top RUsingGroup(this IR1Top r1Top, IDictionary<IPhilote<IGUsingGroup>, IGUsingGroup> gUsingGroups) {
      foreach (var o in gUsingGroups) {
        r1Top.RUsingGroup(o.Value);
      }
      return r1Top;
    }
  }
}
