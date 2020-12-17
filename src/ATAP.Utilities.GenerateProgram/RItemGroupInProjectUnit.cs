using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderItemGroupInProjectUnit(this StringBuilder sb, IGItemGroupInProjectUnit gItemGroupInProjectUnit, StringBuilder indent, string indentDelta, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}<!-- {gItemGroupInProjectUnit.GDescription} --> {eol}");  
      if (gItemGroupInProjectUnit.GComment.GStatements.Count >0) {
        foreach (var s in gItemGroupInProjectUnit.GComment.GStatements) {
          sb.Append($"{indent}<!-- {s} --> {eol}");
        }
      }
      sb.Append($"{indent}<ItemGroup>{eol}");
      foreach (var s in gItemGroupInProjectUnit.GBody.GStatements) {
        sb.Append($"{indent}{indentDelta}{s}{eol}");
      }
      sb.Append($"{indent}</ItemGroup>{eol}");
      return sb;

    }
    public static IR1Top RItemGroupInProjectUnit(this IR1Top r1Top, IGItemGroupInProjectUnit gItemGroupInProjectUnit) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      r1Top.Sb.RenderItemGroupInProjectUnit(gItemGroupInProjectUnit, r1Top.Indent, r1Top.IndentDelta, r1Top.Eol, r1Top.Ct);
      r1Top.Sb.Append(r1Top.Eol);
      return r1Top;
    }
    public static IR1Top RItemGroupInProjectUnit(this IR1Top r1Top, IList<IGItemGroupInProjectUnit> gItemGroupInProjectUnits) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      foreach (var o in gItemGroupInProjectUnits) {
        r1Top.RItemGroupInProjectUnit(o);
      }
      return r1Top;
    }
    public static IR1Top RItemGroupInProjectUnit(this IR1Top r1Top, IDictionary<IPhilote<IGItemGroupInProjectUnit>, IGItemGroupInProjectUnit> gItemGroupInProjectUnits) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      foreach (var kvp in gItemGroupInProjectUnits) {
        r1Top.RItemGroupInProjectUnit(kvp.Value);
      }
      return r1Top;
    }
  }
}
