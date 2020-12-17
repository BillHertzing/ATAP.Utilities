

using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {

    public static IR1Top RMethodGroup(this IR1Top r1Top, IGMethodGroup gMethodGroup) {
      r1Top.Sb.Append($"{r1Top.Indent}#region {gMethodGroup.GName}{r1Top.Eol}");
      r1Top.Indent.Append(r1Top.IndentDelta);
      foreach (var o in gMethodGroup.GMethods) {
        r1Top.RMethod(o.Value);
      }
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.Append($"{r1Top.Indent}#endregion {r1Top.Eol}");
      return r1Top;
    }
    public static IR1Top RMethodGroup(this IR1Top r1Top, IEnumerable<IGMethodGroup> gMethodGroups) {
      foreach (var o in gMethodGroups) {
        r1Top.RMethodGroup(o);
      }
      return r1Top;
    }
    public static IR1Top RMethodGroup(this IR1Top r1Top, IDictionary<IPhilote<IGMethodGroup>, IGMethodGroup> gMethodGroups) {
      foreach (var o in gMethodGroups) {
        r1Top.RMethodGroup(o.Value);
      }
      return r1Top;
    }
  }
}
