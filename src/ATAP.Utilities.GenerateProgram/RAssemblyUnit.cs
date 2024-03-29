using System;
using System.Collections.Generic;
using System.Drawing.Text;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static IR1Top RAssemblyUnit(this IR1Top r1Top, IGAssemblyUnit gAssemblyUnit, IW1Top w1Top) {
      r1Top.Ct?.ThrowIfCancellationRequested();
      // This primarly changes the path where the AssemblyUnits' child Units are written
      var _savepath = w1Top.BasePath;
      w1Top.WAssemblyUnit(gAssemblyUnit);
      w1Top.BasePath = Path.Combine(w1Top.BasePath, gAssemblyUnit.GRelativePath);
      if (gAssemblyUnit.GCompilationUnits.Any()) {
        foreach (var kvp in gAssemblyUnit.GCompilationUnits) {
          r1Top.RCompilationUnit(kvp.Value,w1Top);
          r1Top.Sb.Clear();
        }
      }
      if (gAssemblyUnit.GPropertiesUnits.Any()) {
        foreach (var kvp in gAssemblyUnit.GPropertiesUnits) {
          //r1Top.RPropertiesUnit(kvp.Value,w1Top);
          r1Top.Sb.Clear();
        }
      }
      if (gAssemblyUnit.GResourceUnits.Any()) {
        foreach (var kvp in gAssemblyUnit.GResourceUnits) {
          r1Top.RResourceUnit(kvp.Value,w1Top);
          r1Top.Sb.Clear();
        }
      }
      r1Top.RProjectUnit(gAssemblyUnit.GProjectUnit,w1Top);
      // Change the Top path back to its state before the AssemblyUnit is rendered
     // DirectoryInfo assemblyParentPathDirectoryInfo = Directory.GetParent(w1Top.BasePath);
     //ToDo: re-architect to ensure the main path variable is restored, or, do assemblies and their paths on different thread-local data and async with throtleing and backpressure 
      w1Top.BasePath = _savepath;

      return r1Top;
    }
    public static IR1Top RAssemblyUnit(this IR1Top r1Top, List<IGAssemblyUnit> gAssemblyUnits,IW1Top w1Top) {
      foreach (var o in gAssemblyUnits) {
        r1Top.RAssemblyUnit(o, w1Top);
      }
      return r1Top;
    }

    public static IR1Top RAssemblyUnit(this IR1Top r1Top, IDictionary<IPhilote<IGAssemblyUnit>, IGAssemblyUnit> gAssemblyUnits,IW1Top w1Top) {
      foreach (var kvp in gAssemblyUnits) {
        r1Top.RAssemblyUnit(kvp.Value, w1Top);
      }
      return r1Top;
    }
  }
}
