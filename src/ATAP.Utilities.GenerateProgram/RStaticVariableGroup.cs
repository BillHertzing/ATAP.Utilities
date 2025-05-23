

using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {

    public static IR1Top RStaticVariableGroup(this IR1Top r1Top, IGStaticVariableGroup gStaticVariableGroup) {
      r1Top.Sb.Append($"{r1Top.Indent}#region {gStaticVariableGroup.GName}{r1Top.Eol}");
      r1Top.Indent.Append(r1Top.IndentDelta);
      foreach (var o in gStaticVariableGroup.GStaticVariables) {
        r1Top.RStaticVariable(o.Value);
      }
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.Append($"{r1Top.Indent}#endregion {r1Top.Eol}");
      return r1Top;
    }
    public static IR1Top RStaticVariableGroup(this IR1Top r1Top, IEnumerable<IGStaticVariableGroup> gStaticVariableGroups) {
      foreach (var o in gStaticVariableGroups) {
        r1Top.RStaticVariableGroup(o);
      }
      return r1Top;
    }
    public static IR1Top RStaticVariableGroup(this IR1Top r1Top, IDictionary<IPhilote<IGStaticVariableGroup>, IGStaticVariableGroup> gStaticVariableGroups) {
      foreach (var o in gStaticVariableGroups) {
        r1Top.RStaticVariableGroup(o.Value);
      }
      return r1Top;
    }
  }
}
