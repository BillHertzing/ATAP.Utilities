using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderStatementListStatementStringBuilder(this StringBuilder sb, string statement, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{indent}{statement}{eol}");
    }
    public static IR1Top RStatementList(this IR1Top r1Top, IEnumerable<string> gStatementList) {
      foreach (var s in gStatementList) {
        r1Top.Sb.RenderStatementListStatementStringBuilder(s, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      }
      return r1Top;
    }

  }
}
