using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static StringBuilder RenderInterfacePropertyStringBuilder(this StringBuilder sb, IGProperty gProperty, StringBuilder indent, string eol, CancellationToken? ct = default) {
      return sb.Append($"{indent}{gProperty.GType} {gProperty.GName} {gProperty.GAccessors}{eol}");
    }

    public static IR1Top RInterfaceProperty(this IR1Top r1Top, IGProperty gProperty) {
      r1Top.Sb.RenderInterfacePropertyStringBuilder(gProperty, r1Top.Indent, r1Top.Eol, r1Top.Ct);
      return r1Top;
    }

    public static IR1Top RInterfaceProperty(this IR1Top r1Top, IList<IGProperty> gPropertys) {
      foreach (var o in gPropertys) {
        r1Top.RInterfaceProperty(o);
      }
      return r1Top;
    }
    public static IR1Top RInterfaceProperty(this IR1Top r1Top, IDictionary<IPhilote<IGProperty>, IGProperty> gPropertys) {
      foreach (var kvp in gPropertys) {
        r1Top.RInterfaceProperty(kvp.Value);
      }
      return r1Top;
    }
  }
}
