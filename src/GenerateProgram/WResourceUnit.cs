using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class WriteExtensions {
    public static IW1Top WResourceUnit(this IW1Top w1Top, GResourceUnit gResourceUnit, StringBuilder sB, CancellationToken? ct = default) {

      string path = Path.Combine(w1Top.BasePath, gResourceUnit.GRelativePath, gResourceUnit.GName+gResourceUnit.GFileSuffix);
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
      return w1Top;
    }

  }
}
