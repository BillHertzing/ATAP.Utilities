using System.Text;
using System.Threading;

namespace ATAP.Utilities.GenerateProgram
{
  public static partial class RenderExtensions
  {
  //  public static StringBuilder RenderInterfaceMethodDeclarationStringBuilder(this StringBuilder sb, GMethodDeclaration gMethodDeclaration, StringBuilder indent, string eol, CancellationTokenFromCaller? ct = default) {
  //    ct?.ThrowIfCancellationRequested();
  //    sb.Append($"{indent}{gMethodDeclaration.GVisibility} ");
  //    if (gMethodDeclaration.IsStatic!=null && (bool)gMethodDeclaration.IsStatic) {
  //      sb.Append("static ");
  //    }
  //    if (gMethodDeclaration.IsConstructor!=null && !(bool)gMethodDeclaration.IsConstructor) {
  //      sb.Append($"{gMethodDeclaration.GType} ");
  //    }

  //    sb.Append($"{gMethodDeclaration.GName} (");
  //    sb.RenderArgumentStringBuilder(gMethodDeclaration.GArguments);
  //    sb.Append($");{eol}");
  //    return sb;
  //  }
  //  public static IR1Top RInterfaceMethodDeclaration(this IR1Top r1Top, GMethodDeclaration gMethodDeclaration)
  //  {
  //    r1Top.Sb.RenderInterfaceMethodDeclarationStringBuilder(gMethodDeclaration, r1Top.Indent, r1Top.Eol, r1Top.Ct);
  //    return r1Top;
  //  }
  }
}
