using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderResourceInProjectUnitStringBuilder(this StringBuilder sb, GResourceUnit gResourceUnit, StringBuilder indent, string indentDelta, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append(
        $"{indent}<EmbeddedResource Update=\"{gResourceUnit.GRelativePath}/{gResourceUnit.GName}{gResourceUnit.GFileSuffix}\">{eol}");
      sb.Append($"{indent}{indentDelta}<Generator>ResXFileCodeGenerator</Generator >{eol}");
      sb.Append($"{indent}{indentDelta}<LastGenOutput>{gResourceUnit.GName}.Designer.cs</LastGenOutput>{eol}");
      sb.Append($"{indent}</EmbeddedResource>{eol}");
      sb.Append($"{indent}<Compile Update=\"{gResourceUnit.GRelativePath}/{gResourceUnit.GName}.Designer.cs\">{eol}");
      sb.Append($"{indent}{indentDelta}<DesignTime>True</DesignTime>{eol}");
      sb.Append($"{indent}{indentDelta}<AutoGen >True</AutoGen>{eol}");
      sb.Append($"{indent}{indentDelta}<DependentUpon>{gResourceUnit.GName}{gResourceUnit.GFileSuffix}</DependentUpon>{eol}");
      sb.Append($"{indent}</Compile>{eol}");
      return sb;
    }
    public static IR1Top RResourceUnitInProjectUnit(this IR1Top r1Top, GResourceUnit gResourceUnit) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      r1Top.Sb.RenderResourceInProjectUnitStringBuilder(gResourceUnit, r1Top.Indent, r1Top.IndentDelta, r1Top.Eol, r1Top.Ct);
      return r1Top;
    }

  }
}
