using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderArgumentStringBuilder(this StringBuilder sb, IGArgument gArgument,  CancellationToken? ct = default) {
      if (gArgument.IsRef) {
        sb.Append("ref ");
      }
      if (gArgument.IsOut) {
        sb.Append("out ");
      }
      return sb.Append($"{gArgument.GType} {gArgument.GName}");
    }
    public static StringBuilder RenderArgumentStringBuilder(this StringBuilder sb, IEnumerable<IGArgument>  gArguments,  CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      foreach (var ma in gArguments) {
        sb.RenderArgumentStringBuilder(ma);
      }
      return sb;
    }
    public static StringBuilder RenderArgumentStringBuilder(this StringBuilder sb, IDictionary<IPhilote<IGArgument>, IGArgument>  gArguments,  CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      foreach (var kvp in gArguments) {
        sb.RenderArgumentStringBuilder(kvp.Value);
      }
      return sb;
    }
    public static IR1Top RArgument(this IR1Top r1Top, IGArgument gArgument) {
      r1Top.Sb.RenderArgumentStringBuilder(gArgument, r1Top.Ct);
      return r1Top;
    }
    public static IR1Top RArgument(this IR1Top r1Top, IEnumerable<IGArgument> gArguments) {
      var args = new List<string>();
      StringBuilder sb = new StringBuilder();
      foreach (var ma in gArguments) {
        sb.RenderArgumentStringBuilder(ma, r1Top.Ct);
        args.Add(sb.ToString());
      }
      r1Top.Sb.Append(string.Join(",",args));
      return r1Top;
    }
    public static IR1Top RArgument(this IR1Top r1Top, IDictionary<IPhilote<IGArgument>, IGArgument> gArguments) {
      var args = new List<string>();
      StringBuilder sb = new StringBuilder();
      foreach (var kvp in gArguments) {
        sb.RenderArgumentStringBuilder(kvp.Value, r1Top.Ct);
        args.Add(sb.ToString());
        sb.Clear();
      }
      r1Top.Sb.Append(string.Join(", ",args));
      return r1Top;
    }
  }
}
