using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using ATAP.Utilities.GenerateProgram;


namespace ATAP.Utilities.GenerateProgram {
  public static partial class GBodyExtensions {
    public static GBody AddBody(this GBody gBody, GBody gAdditionalBody) {
      gBody.GStatements.AddRange(gAdditionalBody.GStatements);
      return gBody;
    }
    public static GBody AddBody(this GBody gBody, IEnumerable<GBody> gBodys) {
      foreach (var o in gBodys) {
        gBody.GStatements.AddRange(o.GStatements);
      }
      return gBody;
    }
    //public static GBody AddBodyGroups(this GBody gBody, GBodyGroup gBodyGroup) {
    //  gBody.GBodyGroups[gBodyGroup.Philote] = gBodyGroup;
    //  return gBody;
    //}
    //public static GBody AddBodyGroups(this GBody gBody, IEnumerable<GBodyGroup> gBodyGroups) {
    //  foreach (var o in gBodyGroups) {
    //    gBody.GBodyGroups[o.Philote] = o;
    //  }
    //  return gBody;
    //}
    
  }
}
