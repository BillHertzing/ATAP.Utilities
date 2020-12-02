using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class FetchExtensions {
    public static StringBuilder FetchFileAsStringBuilder(this StringBuilder stringBuilder, string path,
      CancellationToken? ct = default) {

      using (var stream = new FileStream(
        //path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, useAsync: false, ct)) { // ToDo: use async
        path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096)) {
        byte[] buffer = new byte[4096];
        int numRead = -1;
        while (numRead != 0) {
          try {
            numRead = stream.Read(buffer, 0, buffer.Length);
          }
          catch (IOException e) {
            // ToDo: better exception handling
            Console.WriteLine(e);
            throw;
          }

          string text = Encoding.UTF8.GetString(buffer, 0, numRead);
          stringBuilder.Append(text);
        }
      }

      return stringBuilder;
    }
  }
}
