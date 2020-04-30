using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static IR1Top RCompilationUnit(this IR1Top r1Top,GCompilationUnit gCompilationUnit, IW1Top w1Top) {
      r1Top.R1TopData.Ct?.ThrowIfCancellationRequested();
      if (gCompilationUnit.GUsingGroups.Any()) {
          r1Top.RUsingGroup(gCompilationUnit.GUsingGroups);
      }
      if (gCompilationUnit.GUsings.Any()) {
        foreach (var kvp in gCompilationUnit.GUsings) {
          r1Top.RUsing(kvp.Value);
        }
      }
      if (gCompilationUnit.GNamespaces.Any()) {
        foreach (var kvp in gCompilationUnit.GNamespaces) {
          r1Top.RNamespace(kvp.Value);
        }
      }
      w1Top.WCompilationUnit(gCompilationUnit, r1Top.Sb);
      return r1Top;
    }
    public static IR1Top RCompilationUnit(this IR1Top r1Top, List<GCompilationUnit> gCompilationUnits,IW1Top w1Top) {
      foreach (var o in gCompilationUnits) {
        r1Top.RCompilationUnit(o, w1Top);
      }
      return r1Top;
    }

    public static IR1Top RCompilationUnit(this IR1Top r1Top, Dictionary<Philote<GCompilationUnit>, GCompilationUnit> gCompilationUnits,IW1Top w1Top) {
      foreach (var kvp in gCompilationUnits) {
        r1Top.RCompilationUnit(kvp.Value, w1Top);
      }
      return r1Top;
    }
  }
}
