using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.StronglyTypedId;
using ATAP.Utilities.GenerateProgram;
using static ATAP.Utilities.Collection.Extensions;


namespace ATAP.Utilities.GenerateProgram {
  public static partial class GBodyExtensions {
    public static IGBody AddBody(this IGBody gBody, IGBody gAdditionalBody) {
      gBody.GStatements.AddRange(gAdditionalBody.GStatements);
      return gBody;
    }
    public static IGBody AddBody(this IGBody gBody, IEnumerable<IGBody> gBodys) {
      foreach (var o in gBodys) {
        gBody.GStatements.AddRange(o.GStatements);
      }
      return gBody;
    }
    //public static IGBody AddBodyGroups(this IGBody gBody, IGBodyGroup gBodyGroup) {
    //  gBody.GBodyGroups[gBodyGroup.Id] = gBodyGroup;
    //  return gBody;
    //}
    //public static IGBody AddBodyGroups(this IGBody gBody, IEnumerable<IGBodyGroup> gBodyGroups) {
    //  foreach (var o in gBodyGroups) {
    //    gBody.GBodyGroups[o.Id] = o;
    //  }
    //  return gBody;
    //}

  }
}



