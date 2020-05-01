using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderClassFirstLineStringBuilder(this StringBuilder sb, GClass gClass, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}{gClass.GVisibility} class {gClass.GName} ");
      if (gClass.GInheritance != null || (gClass.GImplements != null && gClass.GImplements.Any())) { sb.Append(" : "); }
      if (gClass.GInheritance != null && (gClass.GImplements == null || !gClass.GImplements.Any())) { sb.Append(gClass.GInheritance); }
      else if (gClass.GInheritance == null && (gClass.GImplements != null && gClass.GImplements.Any())) { sb.Append(String.Join(",", gClass.GImplements)); }
      else if (gClass.GInheritance != null && (gClass.GImplements != null && gClass.GImplements.Any())) {
        sb.Append(gClass.GInheritance);
        sb.Append(",");
        sb.Append(String.Join(",", gClass.GImplements));
      }
      sb.Append($" {{{eol}");
      return sb;
    }
    public static StringBuilder RenderClassPreambleStringBuilder(this StringBuilder sb, GClass gClass, StringBuilder indent, string indentDelta, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.RenderClassFirstLineStringBuilder(gClass, indent, eol, ct);
      return sb;
    }
    public static IR1Top RClass(this IR1Top r1Top, GClass gClass) {

      r1Top.Sb.RenderClassFirstLineStringBuilder(gClass, r1Top.R1TopData.Indent, r1Top.R1TopData.Eol, r1Top.R1TopData.Ct);
      r1Top.R1TopData.Indent.Append(r1Top.R1TopData.IndentDelta);
      if (gClass.GPropertyGroups.Any()) {
        r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#region PropertyGroups{r1Top.R1TopData.Eol}");
        r1Top.R1TopData.Indent.Append(r1Top.R1TopData.IndentDelta);
        r1Top.RPropertyGroup(gClass.GPropertyGroups);
        r1Top.R1TopData.Indent.ReplaceFirst(r1Top.R1TopData.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#endregion{r1Top.R1TopData.Eol}");
      }
      if (gClass.GPropertys.Any()) {
        r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#region Property{r1Top.R1TopData.Eol}");
        r1Top.R1TopData.Indent.Append(r1Top.R1TopData.IndentDelta);
        foreach (var kvp in gClass.GPropertys) {
          r1Top.RProperty(kvp.Value);
        }
        r1Top.R1TopData.Indent.ReplaceFirst(r1Top.R1TopData.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#endregion{r1Top.R1TopData.Eol}");
      }
      if (gClass.GConstructors.Any()) {
        r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#region Constructors{r1Top.R1TopData.Eol}");
        r1Top.R1TopData.Indent.Append(r1Top.R1TopData.IndentDelta);
        foreach (var kvp in gClass.GConstructors) {
          r1Top.RMethod(kvp.Value);
        }
        r1Top.R1TopData.Indent.ReplaceFirst(r1Top.R1TopData.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#endregion{r1Top.R1TopData.Eol}");
      }
      if (gClass.GMethods.Any()) {
        r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#region Methods{r1Top.R1TopData.Eol}");
        r1Top.R1TopData.Indent.Append(r1Top.R1TopData.IndentDelta);
        foreach (var kvp in gClass.GMethods) {
          r1Top.RMethod(kvp.Value);
        }
        r1Top.R1TopData.Indent.ReplaceFirst(r1Top.R1TopData.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#endregion{r1Top.R1TopData.Eol}");
      }
      if (gClass.GDisposesOf.Any()) {
        r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#region IDisposable Support{r1Top.R1TopData.Eol}");
        r1Top.R1TopData.Indent.Append(r1Top.R1TopData.IndentDelta);
        r1Top.RDisposesOf(gClass.GDisposesOf);
        r1Top.R1TopData.Indent.ReplaceFirst(r1Top.R1TopData.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.R1TopData.Indent}#endregion{r1Top.R1TopData.Eol}");
      }
      r1Top.R1TopData.Indent.ReplaceFirst(r1Top.R1TopData.IndentDelta, "");
      r1Top.Sb.Append($"}}{r1Top.R1TopData.Eol}");
      return r1Top;
    }
    public static IR1Top RClass(this IR1Top r1Top, Dictionary<Philote<GClass>, GClass> gClasss) {
      foreach (var kvp in gClasss) {
        r1Top.RClass(kvp.Value);
      }
      return r1Top;
    }

  }
}
