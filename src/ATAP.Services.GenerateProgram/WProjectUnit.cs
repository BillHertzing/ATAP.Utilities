using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class WriteExtensions {
    public static IW1Top WProjectUnit(this IW1Top w1Top, GProjectUnit gProjectUnit, StringBuilder sB, CancellationToken? ct = default) {
      var pathToDir = Path.Combine(w1Top.BasePath, gProjectUnit.GRelativePath);
      var pathToFile = Path.Combine(w1Top.BasePath, gProjectUnit.GRelativePath, gProjectUnit.GName+gProjectUnit.GFileSuffix);
      var transformDictionary = gProjectUnit.GPatternReplacement.GDictionary;
      IW1Top iW1Top;
      try {
        iW1Top = w1Top.WFile(pathToDir, pathToFile, transformDictionary, sB, ct);
      }
      catch (Exception e) {
        Console.WriteLine(e); // ToDo: better exception handling
        throw;
      }
      sB.Clear();
      return iW1Top;
    }
  }
}
