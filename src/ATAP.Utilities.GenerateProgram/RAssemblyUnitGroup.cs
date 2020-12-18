using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class RenderExtensions {
    public static IR1Top RAssemblyGroup(this IR1Top r1Top, IGAssemblyGroup gAssemblyGroup, IW1Top w1Top) {
      foreach (var o in gAssemblyGroup.GAssemblyUnits) {
        r1Top.RAssemblyUnit(o.Value, w1Top);
      }
      return r1Top;
    }
    public static IR1Top RAssemblyGroup(this IR1Top r1Top, IEnumerable<IGAssemblyGroup> gAssemblyGroups, IW1Top w1Top) {
      foreach (var o in gAssemblyGroups) {
        r1Top.RAssemblyGroup(o,w1Top);
      }
      return r1Top;
    }
    public static IR1Top RAssemblyGroup(this IR1Top r1Top, IDictionary<IPhilote<IGAssemblyGroup>, IGAssemblyGroup> gAssemblyGroups, IW1Top w1Top) {
      foreach (var o in gAssemblyGroups) {
        r1Top.RAssemblyGroup(o.Value,w1Top);
      }
      return r1Top;
    }

  }
}
