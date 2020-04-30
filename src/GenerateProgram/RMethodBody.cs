using System;
using System.Linq;
using System.Text;
using System.Threading;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderMethodBodyStatementStringBuilder(this StringBuilder sb, string statement, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{indent}{statement}{eol}");
    }
    public static IR1Top RMethodBody(this IR1Top r1Top, GMethodBody gMethodBody) {
      foreach (var s in gMethodBody.StatementList) {
        r1Top.Sb.RenderMethodBodyStatementStringBuilder(s, r1Top.R1TopData.Indent, r1Top.R1TopData.Eol, r1Top.R1TopData.Ct);
      }
      return r1Top;
    }

  }
}
