using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using GenerateProgram;

namespace GenerateProgram {
  public static partial class GUsingGroupExtensions {
    public static GUsingGroup AddUsing(this GUsingGroup gUsingGroup, GUsing gUsing) {
      gUsingGroup.GUsings[gUsing.Philote] = (gUsing);
      return gUsingGroup;
    }
    public static GUsingGroup AddUsing(this GUsingGroup gUsingGroup, IEnumerable<GUsing> gUsing) {
      foreach (var o in gUsing) {
        gUsingGroup.GUsings[o.Philote] = o;
      }
      return gUsingGroup;
    }

    public static GUsingGroup AddUsing(this GUsingGroup gUsingGroup, Dictionary<Philote<GUsing>, GUsing> gUsing) {
      foreach (var kvp in gUsing) {
        gUsingGroup.GUsings[kvp.Key] = kvp.Value;
      }
      return gUsingGroup;
    }
    public static GUsingGroup AddUsingGroup(this GUsingGroup gUsingGroup, GUsingGroup gUsingGroups) {
      foreach (var kvp in gUsingGroups.GUsings) {
        gUsingGroup.AddUsing(kvp.Value);
      }
      return gUsingGroup;
    }

    public static GUsingGroup AddUsingGroup(this GUsingGroup gUsingGroup, IEnumerable<GUsingGroup> gUsingGroups) {
      foreach (var o in gUsingGroups) {
        gUsingGroup.AddUsingGroup(o);
      }
      return gUsingGroup;
    }

    public static GUsingGroup UsingsForMicrosoftGenericHost() {
      var _gUsingGroup = new GUsingGroup("Usings For Microsoft GenericHost");
      foreach (var gName in new List<string>() {
        "Microsoft.Extensions.Localization","Microsoft.Extensions.Options","Microsoft.Extensions.Configuration","Microsoft.Extensions.Logging",
        "Microsoft.Extensions.Logging.Abstractions", "Microsoft.Extensions.DependencyInjection", "Microsoft.Extensions.Hosting","Microsoft.Extensions.Hosting.Internal"}) {
        var gUsing = new GUsing(gName);
        _gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      return _gUsingGroup;
    }
  }
}
