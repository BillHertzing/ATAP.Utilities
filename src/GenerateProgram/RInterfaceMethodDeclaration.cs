using System.Text;
using System.Threading;

namespace GenerateProgram
{
  public static partial class RenderExtensions
  {
    public static StringBuilder RenderInterfaceMethodDeclarationStringBuilder(this StringBuilder sb, GMethodDeclaration gMethodDeclaration, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}{gMethodDeclaration.GVisibility} ");
      if (gMethodDeclaration.IsStatic!=null && (bool)gMethodDeclaration.IsStatic) {
        sb.Append("static ");
      }
      if (gMethodDeclaration.IsConstructor!=null && !(bool)gMethodDeclaration.IsConstructor) {
        sb.Append($"{gMethodDeclaration.GType} ");
      }

      sb.Append($"{gMethodDeclaration.GName} (");
      sb.RenderArgumentStringBuilder(gMethodDeclaration.GArguments);
      sb.Append($");{eol}");
      return sb;
    }
    public static IR1Top RInterfaceMethodDeclaration(this IR1Top r1Top, GMethodDeclaration gMethodDeclaration)
    {
      r1Top.Sb.RenderInterfaceMethodDeclarationStringBuilder(gMethodDeclaration, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      return r1Top;
    }
  }
}
/*

<#@ include file="TConstructorDeclarationArgumentGroups.ttinclude" once="true" #>
<#+ // Start of feature control block.
string GenerateConstructorDeclaration(GConstructorDeclaration cd)
{ var sb = new StringBuilder();
sb.Append(cd.GVisibility);
sb.Append(" ");
sb.Append(cd.GName);
sb.Append("(");
var constructorArgumentGroupStrings = new string[cd.GConstructorArgumentGroups.Count];
for (var i = 0; i< cd.GConstructorArgumentGroups.Count; i++ ) {
  constructorArgumentGroupStrings[i] = GenerateConstructorDeclarationArgumentGroup(cd.GConstructorArgumentGroups[i]);
}
sb.Append(String.Join(",",constructorArgumentGroupStrings))
sb.Append(")");
if (cd.GBase != null) {;}
else if (cd.GThis != null) {;}
sb.Append("{"); #>
<#= sb.Tostring() #>
<#+} // End of feature control block. #>
*/
