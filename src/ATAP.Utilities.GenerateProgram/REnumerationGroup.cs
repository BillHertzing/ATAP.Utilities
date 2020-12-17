

using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {

    public static IR1Top REnumerationGroup(this IR1Top r1Top, IGEnumerationGroup gEnumerationGroup) {
      r1Top.Sb.Append($"{r1Top.Indent}#region {gEnumerationGroup.GName}{r1Top.Eol}");
      r1Top.Indent.Append(r1Top.IndentDelta);
      foreach (var o in gEnumerationGroup.GEnumerations) {
        r1Top.REnumeration(o.Value);
      }
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.Append($"{r1Top.Indent}#endregion {r1Top.Eol}");
      return r1Top;
    }
    public static IR1Top REnumerationGroup(this IR1Top r1Top, IEnumerable<IGEnumerationGroup> gEnumerationGroups) {
      foreach (var o in gEnumerationGroups) {
        r1Top.REnumerationGroup(o);
      }
      return r1Top;
    }
    public static IR1Top REnumerationGroup(this IR1Top r1Top, Dictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup> gEnumerationGroups) {
      foreach (var o in gEnumerationGroups) {
        r1Top.REnumerationGroup(o.Value);
      }
      return r1Top;
    }
  }
}
