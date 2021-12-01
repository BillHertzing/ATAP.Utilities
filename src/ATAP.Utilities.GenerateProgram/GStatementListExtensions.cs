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
  public static partial class GStatementListExtensions {
    public static IList<string> AddStatementList(this IList<string> gStatementList, IList<string> gAdditionalStatementList) {
      gStatementList.AddRange(gAdditionalStatementList);
      return gStatementList;
    }
    public static IList<string> AddStatementList(this IList<string> gStatementList, IEnumerable<IList<string>> gStatementLists) {
      foreach (var o in gStatementLists) {
        gStatementList.AddRange(o);
      }
      return gStatementList;
    }
    //public static IGStatementList AddStatementListGroups(this GStatementList gStatementList, GStatementListGroup gStatementListGroup) {
    //  gStatementList.GStatementListGroups[gStatementListGroup.Id] = gStatementListGroup;
    //  return gStatementList;
    //}
    //public static IGStatementList AddStatementListGroups(this GStatementList gStatementList, IEnumerable<GStatementListGroup> gStatementListGroups) {
    //  foreach (var o in gStatementListGroups) {
    //    gStatementList.GStatementListGroups[o.Id] = o;
    //  }
    //  return gStatementList;
    //}

  }
}



