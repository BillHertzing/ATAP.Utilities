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
      r1Top.Sb.RenderInterfacePreambleStringBuilder(gInterface, r1Top.R1TopData.Indent, r1Top.R1TopData.Eol, r1Top.R1TopData.Ct);
      r1Top.R1TopData.Indent.Append(r1Top.R1TopData.IndentDelta);
      r1Top.RInterfaceProperty(gInterface.GPropertys);
      r1Top.RInterfaceMethod(gInterface.GMethods);
      r1Top.R1TopData.Indent.ReplaceFirst(r1Top.R1TopData.IndentDelta,"");
      r1Top.Sb.Append($"{r1Top.R1TopData.Indent} }}{r1Top.R1TopData.Eol}");
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
