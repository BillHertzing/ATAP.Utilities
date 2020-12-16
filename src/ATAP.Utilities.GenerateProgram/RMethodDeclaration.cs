using System.Text;
using System.Threading;

namespace ATAP.Utilities.GenerateProgram
{
  public static partial class RenderExtensions
  {
    public static StringBuilder RenderMethodDeclarationPreambleStringBuilder(this StringBuilder sb, GMethodDeclaration gMethodDeclaration, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}{gMethodDeclaration.GVisibility} ");
      sb.Append($"{gMethodDeclaration.GAccessModifier} ");
      if (gMethodDeclaration.IsStatic!=null && (bool)gMethodDeclaration.IsStatic) {
        sb.Append("static ");
      }
      if (gMethodDeclaration.IsConstructor!=null && !(bool)gMethodDeclaration.IsConstructor) {
        sb.Append($"{gMethodDeclaration.GType} ");
      }
      sb.Append($"{gMethodDeclaration.GName}(");
      return sb;
    }
    public static IR1Top RMethodDeclaration(this IR1Top r1Top, GMethodDeclaration gMethodDeclaration)
    {
      r1Top.Sb.RenderMethodDeclarationPreambleStringBuilder(gMethodDeclaration, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.RArgument(gArguments: gMethodDeclaration.GArguments);
      if (gMethodDeclaration.GBase != "") {
        r1Top.Sb.Append($") : base({gMethodDeclaration.GBase})");
      } else if (gMethodDeclaration.GThis != "") {
        r1Top.Sb.Append($") : this({gMethodDeclaration.GThis})");
      }
      else {
        r1Top.Sb.Append($")");
      }
      if (!gMethodDeclaration.IsForInterface) {
        r1Top.Sb.Append($" {{{r1Top.Eol}");
      }
      else {
        r1Top.Sb.Append($";{r1Top.Eol}");
      }

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
