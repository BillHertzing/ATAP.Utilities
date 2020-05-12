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
      r1Top.Sb.RenderNamespaceDeclarationStringBuilder(gNamespace, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.Indent.Append(r1Top.IndentDelta);
      r1Top.RClass(gNamespace.GClasss);
      r1Top.RInterface(gNamespace.GInterfaces);
      r1Top.RDelegateGroup(gNamespace.GDelegateGroups);
      r1Top.RDelegate(gNamespace.GDelegates);
      r1Top.REnumerationGroup(gNamespace.GEnumerationGroups);
      r1Top.REnumeration(gNamespace.GEnumerations);
      r1Top.Indent.ReplaceFirst(r1Top.IndentDelta, "");
      r1Top.Sb.RenderNamespaceTerminationStringBuilder(gNamespace, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      return r1Top;
    }
  }
}
