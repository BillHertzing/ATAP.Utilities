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
  public static partial class GStatementListExtensions {
    public static List<string> AddStatementList(this List<string> gStatementList, List<string> gAdditionalStatementList) {
      gStatementList.AddRange(gAdditionalStatementList);
      return gStatementList;
    }
    public static List<string> AddStatementList(this List<string> gStatementList, IEnumerable<List<string>> gStatementLists) {
      foreach (var o in gStatementLists) {
        gStatementList.AddRange(o);
      }
      return gStatementList;
    }
    //public static GStatementList AddStatementListGroups(this GStatementList gStatementList, GStatementListGroup gStatementListGroup) {
    //  gStatementList.GStatementListGroups[gStatementListGroup.Philote] = gStatementListGroup;
    //  return gStatementList;
    //}
    //public static GStatementList AddStatementListGroups(this GStatementList gStatementList, IEnumerable<GStatementListGroup> gStatementListGroups) {
    //  foreach (var o in gStatementListGroups) {
    //    gStatementList.GStatementListGroups[o.Philote] = o;
    //  }
    //  return gStatementList;
    //}
    
  }
}
