using System.Text;
using System.Threading;

namespace GenerateProgram {

  public static partial class RenderExtensions {
    public static StringBuilder RenderNamespaceDeclarationStringBuilder(this StringBuilder sb, GNamespace gNamespace, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{indent}namespace {gNamespace.GName} {{{eol}");
    }
    public static StringBuilder RenderNamespaceTerminationStringBuilder(this StringBuilder sb, GNamespace gNamespace, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      return sb.Append($"{indent}}}{eol}");
    }
    public static IR1Top RNamespace(this IR1Top r1Top, GNamespace gNamespace) {
      r1Top.Sb.RenderNamespaceDeclarationStringBuilder(gNamespace, r1Top.R1TopData.Indent, r1Top.R1TopData.Eol, r1Top.R1TopData.Ct);
      r1Top.R1TopData.Indent.Append(r1Top.R1TopData.IndentDelta);
      r1Top.RClass(gNamespace.GClasss);
      r1Top.R1TopData.Indent.ReplaceFirst(r1Top.R1TopData.IndentDelta, "");
      r1Top.Sb.RenderNamespaceTerminationStringBuilder(gNamespace, r1Top.R1TopData.Indent, r1Top.R1TopData.Eol, r1Top.R1TopData.Ct);
      return r1Top;
    }
  }
}
