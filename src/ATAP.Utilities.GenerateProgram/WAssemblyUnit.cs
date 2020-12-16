using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class WriteExtensions {
    public static IW1Top WAssemblyUnit(this IW1Top w1Top, GAssemblyUnit gAssemblyUnit, StringBuilder? sB = default, CancellationToken? ct = default) {
      ct?.ThrowIfCancellationRequested();
      var path = Path.Combine(w1Top.BasePath, gAssemblyUnit.GRelativePath);
      var dirInfo = new DirectoryInfo(path);
      if (!dirInfo.Exists) {
        if (!(bool)w1Top.Force) {
          //ToDo: Log exception
          throw new Exception(message: $"Relative directory for Generated code does not exist (try force=true): {path}");
        }
        else {
          try {
            dirInfo.Create();
          }
          catch (System.IO.IOException e) {
            //ToDo: Log exception
            throw new Exception(message: $"Could not create relative directory for Generated code: {path}", innerException: e);
          }
        }
      }
      return w1Top;
    }

  }
}
