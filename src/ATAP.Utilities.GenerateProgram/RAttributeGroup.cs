

using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {

    public static IR1Top RAttributeGroup(this IR1Top r1Top, GAttributeGroup gAttributeGroup) {
      r1Top.Sb.Append($"{r1Top.Indent}#region {gAttributeGroup.GName}{r1Top.Eol}");
      r1Top.Indent.Append(r1Top.IndentDelta);
      foreach (var o in gAttributeGroup.GAttributes) {
        r1Top.RAttribute(o.Value);
      }
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.Append($"{r1Top.Indent}#endregion {r1Top.Eol}");
      return r1Top;
    }
    public static IR1Top RAttributeGroup(this IR1Top r1Top, IEnumerable<GAttributeGroup> gAttributeGroups) {
      foreach (var o in gAttributeGroups) {
        r1Top.RAttributeGroup(o);
      }
      return r1Top;
    }
    public static IR1Top RAttributeGroup(this IR1Top r1Top, Dictionary<Philote<GAttributeGroup>, GAttributeGroup> gAttributeGroups) {
      foreach (var o in gAttributeGroups) {
        r1Top.RAttributeGroup(o.Value);
      }
      return r1Top;
    }
  }
}
