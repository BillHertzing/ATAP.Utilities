using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GArgumentExtensions {
    public static string ToBaseString(this Dictionary<Philote<GArgument>, GArgument> gArguments) {
      var aList = new List<string>();
      foreach (var o in gArguments) {
        aList.Add(o.Value.GName);
      }
      return string.Join(",", aList);
    }
  }
}

