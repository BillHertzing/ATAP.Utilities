using System.Collections.Generic;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class RenderExtensions {
    public static IR1Top RAssemblyGroup(this IR1Top r1Top, GAssemblyGroup gAssemblyGroup, IW1Top w1Top) {
      foreach (var o in gAssemblyGroup.GAssemblyUnits) {
        r1Top.RAssemblyUnit(o.Value, w1Top);
      }
      return r1Top;
    }
    public static IR1Top RAssemblyGroup(this IR1Top r1Top, IEnumerable<GAssemblyGroup> gAssemblyGroups, IW1Top w1Top) {
      foreach (var o in gAssemblyGroups) {
        r1Top.RAssemblyGroup(o,w1Top);
      }
      return r1Top;
    }
    public static IR1Top RAssemblyGroup(this IR1Top r1Top, Dictionary<Philote<GAssemblyGroup>, GAssemblyGroup> gAssemblyGroups, IW1Top w1Top) {
      foreach (var o in gAssemblyGroups) {
        r1Top.RAssemblyGroup(o.Value,w1Top);
      }
      return r1Top;
    }

  }
}
