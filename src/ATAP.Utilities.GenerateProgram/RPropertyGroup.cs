using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static IR1Top RPropertyGroup(this IR1Top r1Top, IGPropertyGroup gPropertyGroup) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      r1Top.Sb.Append($"{r1Top.Indent}#region {gPropertyGroup.GName}{r1Top.Eol}");
      r1Top.Indent.Append(r1Top.IndentDelta);
      r1Top.RProperty(gPropertyGroup.GPropertys);
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta,"");
      r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      return r1Top;
    }
    public static IR1Top RPropertyGroup(this IR1Top r1Top, IEnumerable<IGPropertyGroup> gPropertyGroups) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      foreach (var o in gPropertyGroups) {
        r1Top.RPropertyGroup(o);
      }
      return r1Top;
    }
    public static IR1Top RPropertyGroup(this IR1Top r1Top, IDictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> gPropertyGroups) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      foreach (var kvp in gPropertyGroups) {
        r1Top.RPropertyGroup(kvp.Value);
      }
      return r1Top;
    }
  }
}
