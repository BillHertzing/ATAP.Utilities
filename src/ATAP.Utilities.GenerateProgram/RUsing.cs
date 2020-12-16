using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderUsingStringBuilder(this StringBuilder sb, GUsing gUsing, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{indent}using {gUsing.GName};{eol}");
    }
    public static IR1Top RUsing(this IR1Top r1Top, GUsing gUsing) {
      r1Top.Sb.RenderUsingStringBuilder(gUsing, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      return r1Top;
    }
    public static IR1Top RUsing(this IR1Top r1Top, List<GUsing> gUsings) {
      foreach (var o in gUsings) {
        r1Top.RUsing(o);
      }
      return r1Top;
    }
    public static IR1Top RUsing(this IR1Top r1Top, Dictionary<Philote<GUsing>, GUsing> gUsings) {
      foreach (var o in gUsings) {
        r1Top.RUsing(o.Value);
      }
      return r1Top;
    }
  }
}
