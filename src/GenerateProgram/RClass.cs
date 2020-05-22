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
      sb.Append($"{indent}{gClass.GVisibility} {gClass.GAccessModifier} class {gClass.GName} ");
      if (gClass.GInheritance != "" ||  gClass.GImplements.Any()) { sb.Append(" : "); }
      if (gClass.GInheritance != "" && !gClass.GImplements.Any()) { sb.Append(gClass.GInheritance); }
      else if (gClass.GInheritance == "" && gClass.GImplements.Any()) { sb.Append(String.Join(",", gClass.GImplements)); }
      else if (gClass.GInheritance != "" && gClass.GImplements.Any()) {
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

      r1Top.Sb.RenderClassFirstLineStringBuilder(gClass, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.Indent.Append(r1Top.IndentDelta);
      if (gClass.GPropertyGroups.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region PropertyGroups{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        r1Top.RPropertyGroup(gClass.GPropertyGroups);
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GPropertys.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region Property{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gClass.GPropertys) {
          r1Top.RProperty(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      //var constructorsList = new List<GMethod>();
      //constructorsList.AddRange(gClass.CombinedConstructors());
      //if (constructorsList.Any()) {
      //  r1Top.Sb.Append($"{r1Top.Indent}#region Constructors{r1Top.Eol}");
      //  r1Top.Indent.Append(r1Top.IndentDelta);
      //  foreach (var o in constructorsList) {
      //    r1Top.RMethod(o);
      //  }
      //  r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      //  r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      //}
      if (gClass.GMethodGroups.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region MethodGroups{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gClass.GMethodGroups) {
          r1Top.RMethodGroup(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GMethods.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region Methods{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gClass.GMethods) {
          r1Top.RMethod(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GStaticVariableGroups.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region StaticVariableGroups{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        r1Top.RStaticVariableGroup(gClass.GStaticVariableGroups);
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GStaticVariables.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region StaticVariable{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gClass.GStaticVariables) {
          r1Top.RStaticVariable(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GConstStringGroups.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region ConstStringGroups{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        r1Top.RConstStringGroup(gClass.GConstStringGroups);
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GConstStrings.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region ConstString{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gClass.GConstStrings) {
          r1Top.RConstString(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GDelegateGroups.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region DelegateGroups{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gClass.GDelegateGroups) {
          r1Top.RDelegateGroup(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GDelegates.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region Delegates{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gClass.GDelegates) {
          r1Top.RDelegate(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GEnumerationGroups.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region EnumerationGroups{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gClass.GEnumerationGroups) {
          r1Top.REnumerationGroup(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GEnumerations.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region Enumerations{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        foreach (var kvp in gClass.GEnumerations) {
          r1Top.REnumeration(kvp.Value);
        }
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      if (gClass.GDisposesOf.Any()) {
        r1Top.Sb.Append($"{r1Top.Indent}#region IDisposable Support{r1Top.Eol}");
        r1Top.Indent.Append(r1Top.IndentDelta);
        r1Top.RDisposesOf(gClass.GDisposesOf);
        r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
        r1Top.Sb.Append($"{r1Top.Indent}#endregion{r1Top.Eol}");
      }
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.Append($"}}{r1Top.Eol}");
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
