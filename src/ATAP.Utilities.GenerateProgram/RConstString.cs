using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RConstStringStringBuilder(this StringBuilder sb, IGConstString gConstString, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{indent}const string {gConstString.GName} = \"{gConstString.GValue}\";{eol}");
    }
    public static IR1Top RConstString(this IR1Top r1Top, IGConstString gConstString) {
      r1Top.Sb.RConstStringStringBuilder(gConstString, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      return r1Top;
    }
    public static IR1Top RConstString(this IR1Top r1Top, IEnumerable<IGConstString> gConstStrings) {
      foreach (var o in gConstStrings) {
        r1Top.RConstString(o);
      }
      return r1Top;
    }
    public static IR1Top RConstString(this IR1Top r1Top, IDictionary<IPhilote<IGConstString>, IGConstString> gConstStrings) {
      foreach (var o in gConstStrings) {
        r1Top.RConstString(o.Value);
      }
      return r1Top;
    }
  }
}
