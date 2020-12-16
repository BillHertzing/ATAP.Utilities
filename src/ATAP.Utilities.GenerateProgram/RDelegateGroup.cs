

using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {

    public static IR1Top RDelegateGroup(this IR1Top r1Top, GDelegateGroup gDelegateGroup) {
      r1Top.Sb.Append($"{r1Top.Indent}#region {gDelegateGroup.GName}{r1Top.Eol}");
      r1Top.Indent.Append(r1Top.IndentDelta);
      foreach (var o in gDelegateGroup.GDelegates) {
        r1Top.RDelegate(o.Value);
      }
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.Append($"{r1Top.Indent}#endregion {r1Top.Eol}");
      return r1Top;
    }
    public static IR1Top RDelegateGroup(this IR1Top r1Top, IEnumerable<GDelegateGroup> gDelegateGroups) {
      foreach (var o in gDelegateGroups) {
        r1Top.RDelegateGroup(o);
      }
      return r1Top;
    }
    public static IR1Top RDelegateGroup(this IR1Top r1Top, Dictionary<Philote<GDelegateGroup>, GDelegateGroup> gDelegateGroups) {
      foreach (var o in gDelegateGroups) {
        r1Top.RDelegateGroup(o.Value);
      }
      return r1Top;
    }
  }
}
