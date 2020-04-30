using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static IR1Top RPropertyGroup(this IR1Top r1Top, GPropertyGroup gPropertyGroup) {
      r1Top.R1TopData.Ct?.ThrowIfCancellationRequested();
      r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#region {gPropertyGroup.GName}{r1Top.R1TopData.Eol}");
      r1Top.R1TopData.Indent.Append(r1Top.R1TopData.IndentDelta);
      r1Top.RProperty(gPropertyGroup.GPropertys);
      r1Top.R1TopData.Indent.ReplaceFirst(r1Top.R1TopData.IndentDelta,"");
      r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#endregion{r1Top.R1TopData.Eol}");
      return r1Top;
    }
    public static IR1Top RPropertyGroup(this IR1Top r1Top, List<GPropertyGroup> gPropertyGroups) {
      r1Top.R1TopData.Ct?.ThrowIfCancellationRequested();
      foreach (var o in gPropertyGroups) {
        r1Top.RPropertyGroup(o);
      }
      return r1Top;
    }
    public static IR1Top RPropertyGroup(this IR1Top r1Top, Dictionary<Philote<GPropertyGroup>, GPropertyGroup> gPropertyGroups) {
      r1Top.R1TopData.Ct?.ThrowIfCancellationRequested();
      foreach (var kvp in gPropertyGroups) {
        r1Top.RPropertyGroup(kvp.Value);
      }
      return r1Top;
    }
  }
}
