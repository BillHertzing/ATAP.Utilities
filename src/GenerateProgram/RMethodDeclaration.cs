using System.Text;
using System.Threading;

namespace GenerateProgram
{
  public static partial class RenderExtensions
  {
    public static StringBuilder RenderMethodDeclarationPreambleStringBuilder(this StringBuilder sb, GMethodDeclaration gMethodDeclaration, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      StringBuilder firstLine = new StringBuilder();
      firstLine.Append($"{indent}{gMethodDeclaration.GVisibility} ");
      firstLine.Append($"{gMethodDeclaration.GAccessModifier}");
      if (gMethodDeclaration.IsStatic!=null && (bool)gMethodDeclaration.IsStatic) {
        firstLine.Append("static ");
      }
      if (gMethodDeclaration.IsConstructor!=null && !(bool)gMethodDeclaration.IsConstructor) {
        firstLine.Append($"{gMethodDeclaration.GType} ");
      }
      firstLine.Append($"{gMethodDeclaration.GName}(");
      sb.Append(firstLine);
      return sb;
    }
    public static IR1Top RMethodDeclaration(this IR1Top r1Top, GMethodDeclaration gMethodDeclaration)
    {
      r1Top.Sb.RenderMethodDeclarationPreambleStringBuilder(gMethodDeclaration, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      r1Top.RMethodArgument(gMethodArguments: gMethodDeclaration.GMethodArguments);
      r1Top.Sb.Append($") {{{r1Top.Eol }");
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
