using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderMethodArgumentStringBuilder(this StringBuilder sb, GMethodArgument gMethodArgument,  CancellationToken? ct = default) {
      if (gMethodArgument.IsRef) {
        sb.Append("ref ");
      }
      if (gMethodArgument.IsOut) {
        sb.Append("out ");
      }
      return sb.Append($"{gMethodArgument.GType} {gMethodArgument.GName}");
    }
    public static StringBuilder RenderMethodArgumentStringBuilder(this StringBuilder sb, List<GMethodArgument>  gMethodArguments,  CancellationToken? ct = default) {
      foreach (var ma in gMethodArguments) {
        sb.RenderMethodArgumentStringBuilder(ma);
      }
      return sb;
    }
    public static StringBuilder RenderMethodArgumentStringBuilder(this StringBuilder sb, Dictionary<Philote<GMethodArgument>, GMethodArgument>  gMethodArguments,  CancellationToken? ct = default) {
      foreach (var kvp in gMethodArguments) {
        sb.RenderMethodArgumentStringBuilder(kvp.Value);
      }
      return sb;
    }
    public static IR1Top RMethodArgument(this IR1Top r1Top, GMethodArgument gMethodArgument) {
      r1Top.Sb.RenderMethodArgumentStringBuilder(gMethodArgument, r1Top.R1TopData.Ct);
      return r1Top;
    }
    public static IR1Top RMethodArgument(this IR1Top r1Top, List<GMethodArgument> gMethodArguments) {
      var args = new List<string>();
      StringBuilder sb = new StringBuilder();
      foreach (var ma in gMethodArguments) {
        sb.RenderMethodArgumentStringBuilder(ma, r1Top.R1TopData.Ct);
        args.Add(sb.ToString());
      }
      r1Top.Sb.Append(string.Join(",",args));
      return r1Top;
    }
    public static IR1Top RMethodArgument(this IR1Top r1Top, Dictionary<Philote<GMethodArgument>, GMethodArgument> gMethodArguments) {
      var args = new List<string>();
      StringBuilder sb = new StringBuilder();
      foreach (var kvp in gMethodArguments) {
        sb.RenderMethodArgumentStringBuilder(kvp.Value, r1Top.R1TopData.Ct);
        args.Add(sb.ToString());
        sb.Clear();
      }
      r1Top.Sb.Append(string.Join(", ",args));
      return r1Top;
    }
  }
}
