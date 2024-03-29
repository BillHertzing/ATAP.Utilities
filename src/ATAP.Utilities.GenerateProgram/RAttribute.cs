using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderAttributeStringBuilder(this StringBuilder sb, IGAttribute gAttribute, StringBuilder indent, string eol, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      sb.Append($"{indent}[{gAttribute.GName}]{eol}");
      return sb;
    }
    public static IR1Top RAttribute(this IR1Top r1Top, IGAttribute gAttribute) {
      r1Top.RComment(gAttribute.GComment);
      r1Top.Sb.RenderAttributeStringBuilder(gAttribute, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      return r1Top;
    }

    public static IR1Top RAttribute(this IR1Top r1Top, IEnumerable<IGAttribute> gAttributes) {
      foreach (var o in gAttributes) {
        r1Top.RAttribute(o);
      }
      return r1Top;
    }
    public static IR1Top RAttribute(this IR1Top r1Top, IDictionary<IPhilote<IGAttribute>, IGAttribute> gAttributes) {
      foreach (var kvp in gAttributes) {
        r1Top.RAttribute(kvp.Value);
      }
      return r1Top;
    }
  }
}
