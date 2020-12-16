using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RInterfacePreambleStringBuilder(this StringBuilder sb, GInterface gInterface, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}{gInterface.GVisibility} {gInterface.GAccessModifier} interface {gInterface.GName} ");
      if (gInterface.GInheritance != "" ||  gInterface.GImplements.Any()) { sb.Append(" : "); }
      if (gInterface.GInheritance != "" && !gInterface.GImplements.Any()) { sb.Append(gInterface.GInheritance); }
      else if (gInterface.GInheritance == "" && gInterface.GImplements.Any()) { sb.Append(String.Join(",", gInterface.GImplements)); }
      else if (gInterface.GInheritance != "" && gInterface.GImplements.Any()) {
        sb.Append(gInterface.GInheritance);
        sb.Append(",");
        sb.Append(String.Join(",", gInterface.GImplements));
      }
      sb.Append($" {{{eol}");
      return sb;

    }

    public static IR1Top RInterface(this IR1Top r1Top, GInterface gInterface) {
      r1Top.Sb.RInterfacePreambleStringBuilder(gInterface, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.Indent.Append(r1Top.IndentDelta);
      if (gInterface.GPropertyGroups.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region PropertyGroups{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        r1Top.RPropertyGroup(gInterface.GPropertyGroups);
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gInterface.GPropertys.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region Property{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gInterface.GPropertys) {
          //r1Top.RInterfaceProperty(kvp.Value);
          r1Top.RProperty(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      //r1Top.RInterfaceProperty(gInterface.GPropertys);
      if (gInterface.GMethodGroups.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region MethodGroups{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gInterface.GMethodGroups) {
          r1Top.RMethodGroup(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gInterface.GMethods.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region Methods{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gInterface.GMethods) {
          r1Top.RMethod(kvp.Value);
          //r1Top.RInterfaceMethod(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
 
      //r1Top.RInterfaceMethod(gInterface.GMethods);
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.Append($"{r1Top.Indent} }}{r1Top.Eol}");
      return r1Top;
    }

    public static IR1Top RInterface(this IR1Top r1Top, Dictionary<Philote<GInterface>, GInterface> gInterfaces) {
      foreach (var kvp in gInterfaces) {
        r1Top.RInterface(kvp.Value);
      }
      return r1Top;
    }
    public static IR1Top RInterface(this IR1Top r1Top, IEnumerable<GInterface> gInterfaces) {
      foreach (var o in gInterfaces) {
        r1Top.RInterface(o);
      }
      return r1Top;
    }
    public static IR1Top RInterface(this IR1Top r1Top, IEnumerable<KeyValuePair<Philote<GInterface>, GInterface>> gInterfaces) {
      foreach (var o in gInterfaces) {
        r1Top.RInterface(o.Value);
      }
      return r1Top;
    }
  }
}
