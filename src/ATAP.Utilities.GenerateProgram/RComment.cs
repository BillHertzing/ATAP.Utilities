using System;
using System.Linq;
using System.Text;
using System.Threading;

namespace GenerateProgram {
  public static partial class RenderExtensions {

    public static IR1Top RComment(this IR1Top r1Top, GComment gComment) {
      r1Top.RStatementList(gComment.GStatements);
      return r1Top;
    }

  }
}
