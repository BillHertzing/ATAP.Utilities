using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderStaticVariablePreambleStringBuilder(this StringBuilder sb, GStaticVariable gStaticVariable, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}{gStaticVariable.GVisibility} ");
      sb.Append($"{gStaticVariable.GAccessModifier} static ");
        sb.Append($"{gStaticVariable.GType} ");
      sb.Append($"{gStaticVariable.GName} = {eol}");
      return sb;
    }
    public static IR1Top RStaticVariable(this IR1Top r1Top, GStaticVariable gStaticVariable) {
      r1Top.RComment(gStaticVariable.GComment);
      r1Top.Sb.RenderStaticVariablePreambleStringBuilder(gStaticVariable,r1Top.Indent,r1Top.Eol, r1Top.Ct);
      r1Top.Indent.Append(r1Top.IndentDelta);
      r1Top.RStatementList(gStaticVariable.GBody.GStatements);
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta,"");
      r1Top.Sb.Append($"{r1Top.Indent};{r1Top.Eol}");
      return r1Top;
    }

    public static IR1Top RStaticVariable(this IR1Top r1Top, IEnumerable<GStaticVariable> gStaticVariables) {
      foreach (var o in gStaticVariables) {
        r1Top.RStaticVariable(o);
      }
      return r1Top;
    }
    public static IR1Top RStaticVariable(this IR1Top r1Top, Dictionary<Philote<GStaticVariable>, GStaticVariable> gStaticVariables) {
      foreach (var kvp in gStaticVariables) {
        r1Top.RStaticVariable(kvp.Value);
      }
      return r1Top;
    }
  }
}
