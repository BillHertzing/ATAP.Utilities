using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderPropertyGroupInProjectUnit(this StringBuilder sb, GPropertyGroupInProjectUnit gPropertyGroupInProjectUnit, StringBuilder indent, string indentDelta, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}<!-- {gPropertyGroupInProjectUnit.GDescription} -->{eol}");
      sb.Append($"{indent}<PropertyGroup>{eol}");
      foreach (var s in gPropertyGroupInProjectUnit.GPropertyGroupStatements) {
        sb.Append($"{indent}{indentDelta}{s}{eol}");
      }
      sb.Append($"{indent}</PropertyGroup>{eol}");
      return sb;
    }
    public static IR1Top RPropertyGroupInProjectUnit(this IR1Top r1Top, GPropertyGroupInProjectUnit gPropertyGroupInProjectUnit) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      r1Top.Sb.RenderPropertyGroupInProjectUnit(gPropertyGroupInProjectUnit, r1Top.Indent, r1Top.IndentDelta, r1Top.Eol, r1Top.Ct);
      r1Top.Sb.Append(r1Top.Eol);
      return r1Top;
    }
    public static IR1Top RPropertyGroupInProjectUnit(this IR1Top r1Top, List<GPropertyGroupInProjectUnit> gPropertyGroupInProjectUnits) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      foreach (var o in gPropertyGroupInProjectUnits) {
        r1Top.RPropertyGroupInProjectUnit(o);

      }
      return r1Top;
    }
    public static IR1Top RPropertyGroupInProjectUnit(this IR1Top r1Top, Dictionary<Philote<GPropertyGroupInProjectUnit>, GPropertyGroupInProjectUnit> gPropertyGroupInProjectUnits) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      foreach (var kvp in gPropertyGroupInProjectUnits) {
        r1Top.RPropertyGroupInProjectUnit(kvp.Value);
      }
      return r1Top;
    }
  }
}
