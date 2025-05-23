using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.StronglyTypedId;
using ATAP.Utilities.GenerateProgram;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GUsingGroupExtensions {
    public static IGUsingGroup AddUsing(this IGUsingGroup gUsingGroup, IGUsing gUsing) {
      gUsingGroup.GUsings[gUsing.Id] = (gUsing);
      return gUsingGroup;
    }
    public static IGUsingGroup AddUsing(this IGUsingGroup gUsingGroup, IEnumerable<IGUsing> gUsing) {
      foreach (var o in gUsing) {
        gUsingGroup.GUsings[o.Id] = o;
      }
      return gUsingGroup;
    }

    public static IGUsingGroup AddUsing(this IGUsingGroup gUsingGroup, IDictionary<IGUsingId<TValue>, IGUsing<TValue>> gUsing) {
      foreach (var kvp in gUsing) {
        gUsingGroup.GUsings[kvp.Key] = kvp.Value;
      }
      return gUsingGroup;
    }
    public static IGUsingGroup AddUsingGroup(this IGUsingGroup gUsingGroup, IGUsingGroup gUsingGroups) {
      foreach (var kvp in gUsingGroups.GUsings) {
        gUsingGroup.AddUsing(kvp.Value);
      }
      return gUsingGroup;
    }

    public static IGUsingGroup AddUsingGroup(this IGUsingGroup gUsingGroup, IEnumerable<IGUsingGroup> gUsingGroups) {
      foreach (var o in gUsingGroups) {
        gUsingGroup.AddUsingGroup(o);
      }
      return gUsingGroup;
    }
  }
}



