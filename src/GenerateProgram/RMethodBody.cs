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
    public static IR1Top RMethodBody(this IR1Top r1Top, GStatementList gBody){
      foreach (var s in gBody.GStatements) {
        r1Top.Sb.RenderMethodBodyStatementStringBuilder(s, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      }
      return r1Top;
    }

  }
}
