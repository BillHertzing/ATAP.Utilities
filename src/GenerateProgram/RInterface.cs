using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderInterfacePreambleStringBuilder(this StringBuilder sb, GInterface gInterface, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{indent}interface {gInterface.GName} {{{eol}");
    }

    public static IR1Top RInterface(this IR1Top r1Top, GInterface gInterface) {
      r1Top.Sb.RenderInterfacePreambleStringBuilder(gInterface, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.Indent.Append(r1Top.IndentDelta);
      r1Top.RInterfaceProperty(gInterface.GPropertys);
      r1Top.RInterfaceMethod(gInterface.GMethods);
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta,"");
      r1Top.Sb.Append($"{r1Top.Indent} }}{r1Top.Eol}");
      return r1Top;
    }

    public static IR1Top RInterface(this IR1Top r1Top, List<GInterface> gInterfaces) {
      foreach (var o in gInterfaces) {
        r1Top.RInterface(o);
      }
      return r1Top;
    }
    public static IR1Top RInterface(this IR1Top r1Top, Dictionary<Philote<GInterface>, GInterface> gInterfaces) {
      foreach (var kvp in gInterfaces) {
        r1Top.RInterface(kvp.Value);
      }
      return r1Top;
    }
  }
}
