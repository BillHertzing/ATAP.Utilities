using System.Text;
using System.Threading;

namespace ATAP.Utilities.GenerateProgram
{
  public static partial class RenderExtensions
  {
    public static StringBuilder RenderDelegateDeclarationPreambleStringBuilder(this StringBuilder sb, GDelegateDeclaration gDelegateDeclaration, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}{gDelegateDeclaration.GVisibility} delegate {gDelegateDeclaration.GType} {gDelegateDeclaration.GName}(");
      return sb;
    }
    public static IR1Top RDelegateDeclaration(this IR1Top r1Top, GDelegateDeclaration gDelegateDeclaration)
    {
      r1Top.Sb.RenderDelegateDeclarationPreambleStringBuilder(gDelegateDeclaration, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.RArgument(gArguments: gDelegateDeclaration.GArguments);
      r1Top.Sb.Append($");{r1Top.Eol}");
      return r1Top;
    }
  }
}
