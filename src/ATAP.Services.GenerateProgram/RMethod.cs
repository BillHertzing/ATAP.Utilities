using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static IR1Top RMethod(this IR1Top r1Top, GMethod gMethod) {
      r1Top.RComment(gMethod.GComment);
      r1Top.RMethodDeclaration(gMethod.GDeclaration);
      if (!gMethod.IsForInterface) {
        r1Top.Indent.Append(r1Top.IndentDelta);
        r1Top.RBody(gMethod.GBody);
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.Append($"{r1Top.Indent}}}{r1Top.Eol}");
      }
      return r1Top;
    }

    public static IR1Top RMethod(this IR1Top r1Top, IEnumerable<GMethod> gMethods) {
      foreach (var o in gMethods) {
        r1Top.RMethod(o);
      }
      return r1Top;
    }
    public static IR1Top RMethod(this IR1Top r1Top, Dictionary<Philote<GMethod>, GMethod> gMethods) {
      foreach (var kvp in gMethods) {
        r1Top.RMethod(kvp.Value);
      }
      return r1Top;
    }
  }
}
