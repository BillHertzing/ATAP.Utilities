using System;
using System.Linq;
using System.Text;
using System.Threading;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {

    public static IR1Top RComment(this IR1Top r1Top, IGComment gComment) {
      r1Top.RStatementList(gComment.GStatements);
      return r1Top;
    }

  }
}
