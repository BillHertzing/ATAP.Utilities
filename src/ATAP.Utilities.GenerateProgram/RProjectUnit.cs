using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;


namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderProjectUnitPreambleStringBuilder(this StringBuilder sb, GProjectUnit gProjectUnit, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{StringConstants.ProjectUnitSDKProjectStartTagStringDefault}{eol}");
    }
    public static StringBuilder RenderProjectUnitPostambleStringBuilder(this StringBuilder sb, GProjectUnit gProjectUnit, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{StringConstants.ProjectUnitSDKProjectEndTagStringDefault}{eol}");
    }
    public static IR1Top RProjectUnit(this IR1Top r1Top,GProjectUnit gProjectUnit, IW1Top w1Top) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      r1Top.Sb.RenderProjectUnitPreambleStringBuilder(gProjectUnit, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.Indent.Append(r1Top.IndentDelta);
      r1Top.Sb.Append(r1Top.Eol);
      r1Top.Sb.Append($"{r1Top.IndentDelta}{GProjectUnit.Header}{r1Top.Eol}");
      if (gProjectUnit.GPropertyGroupInProjectUnits.Any()) {
        foreach (var kvp in gProjectUnit.GPropertyGroupInProjectUnits) {
          r1Top.RPropertyGroupInProjectUnit(kvp.Value);
        }
      }
      r1Top.Sb.Append(r1Top.Eol);
      if (gProjectUnit.GItemGroupInProjectUnits.Any()) {
        foreach (var kvp in gProjectUnit.GItemGroupInProjectUnits) {
          r1Top.RItemGroupInProjectUnit(kvp.Value);
        }
      }
      r1Top.Sb.Append(r1Top.Eol);
      if (gProjectUnit.GResourceUnits.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}<ItemGroup>{r1Top.Eol}");
        foreach (var kvp in gProjectUnit.GResourceUnits) {
          r1Top.RResourceUnitInProjectUnit(kvp.Value);
          r1Top.Sb.Append(r1Top.Eol);
        }
        r1Top.Sb.Append($"{r1Top.Indent}</ItemGroup>{r1Top.Eol}");
      }
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.RenderProjectUnitPostambleStringBuilder(gProjectUnit, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.Sb.Append(r1Top.Eol);
      w1Top.WProjectUnit(gProjectUnit, r1Top.Sb);
      return r1Top;
    }
    public static IR1Top RProjectUnit(this IR1Top r1Top, List<GProjectUnit> gProjectUnits,IW1Top w1Top) {
      foreach (var o in gProjectUnits) {
        r1Top.RProjectUnit(o, w1Top);
      }
      return r1Top;
    }

    public static IR1Top RProjectUnit(this IR1Top r1Top, Dictionary<Philote<GProjectUnit>, GProjectUnit> gProjectUnits,IW1Top w1Top) {
      foreach (var kvp in gProjectUnits) {
        r1Top.RProjectUnit(kvp.Value, w1Top);
      }
      return r1Top;
    }
  }
}
