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
      var path = Path.Combine(w1Top.BasePath, gProjectUnit.GRelativePath);
      var dirInfo = new DirectoryInfo( path);
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
      path = Path.Combine(w1Top.BasePath, gProjectUnit.GRelativePath, gProjectUnit.GName+gProjectUnit.GFileSuffix);
      using (var stream = new FileStream(
        path, FileMode.OpenOrCreate, FileAccess.Write, FileShare.Write, 4096, useAsync: false)) {
        var bytes = Encoding.UTF8.GetBytes(sB.ToString());
        try {
          stream.Write(bytes, 0, bytes.Length);
        }
        catch (IOException e) {
          Console.WriteLine(e);
          throw;
        }
      }

      sB.Clear();
      return w1Top;
    }

  }
}
