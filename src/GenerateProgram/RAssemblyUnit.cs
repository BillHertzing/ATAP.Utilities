using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static IR1Top RAssemblyUnit(this IR1Top r1Top,GAssemblyUnit gAssemblyUnit, IW1Top w1Top) {
      r1Top.R1TopData.Ct?.ThrowIfCancellationRequested();
      if (gAssemblyUnit.GCompilationUnits.Any()) {
        foreach (var kvp in gAssemblyUnit.GCompilationUnits) {
          r1Top.RCompilationUnit(kvp.Value,w1Top);
          r1Top.Sb.Clear();
        }
      }
      if (gAssemblyUnit.GPropertiesUnits.Any()) {
        //w1Top.WPropertiesFolder(gAssemblyUnit, r1Top.Sb);
        foreach (var kvp in gAssemblyUnit.GPropertiesUnits) {
          //r1Top.RPropertiesUnit(kvp.Value,w1Top);
          r1Top.Sb.Clear();
        }
      }
      if (gAssemblyUnit.GResourceUnits.Any()) {
        //w1Top.WResourceFolder(gAssemblyUnit, r1Top.Sb);
        foreach (var kvp in gAssemblyUnit.GResourceUnits) {
          r1Top.RResourceUnit(kvp.Value,w1Top);
          r1Top.Sb.Clear();
        }
      }
      return r1Top;
    }
    public static IR1Top RAssemblyUnit(this IR1Top r1Top, List<GAssemblyUnit> gAssemblyUnits,IW1Top w1Top) {
      foreach (var o in gAssemblyUnits) {
        r1Top.RAssemblyUnit(o, w1Top);
      }
      return r1Top;
    }

    public static IR1Top RAssemblyUnit(this IR1Top r1Top, Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit> gAssemblyUnits,IW1Top w1Top) {
      foreach (var kvp in gAssemblyUnits) {
        r1Top.RAssemblyUnit(kvp.Value, w1Top);
      }
      return r1Top;
    }
  }
}
