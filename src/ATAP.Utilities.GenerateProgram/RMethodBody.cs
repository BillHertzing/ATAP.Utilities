using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderBodyStatementStringBuilder(this StringBuilder sb, string statement, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{indent}{statement}{eol}");
    }
    public static IR1Top RBody(this IR1Top r1Top, GBody gBody) {
      r1Top.RComment(gBody.GComment);
      foreach (var s in gBody.GStatements) {
        r1Top.Sb.RenderBodyStatementStringBuilder(s, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      }
      return r1Top;
    }

  }
}
