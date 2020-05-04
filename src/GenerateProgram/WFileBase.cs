using System;
using System.Collections.Generic;
using System.Diagnostics.Eventing.Reader;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class WriteExtensions {
    public static IW1Top WFile(this IW1Top w1Top, string pathToDirectory,string pathToFile, Dictionary<Regex,string> gDictionary, StringBuilder sB, CancellationToken? ct = default) {

      var dirInfo = new DirectoryInfo( pathToDirectory);
      if (!dirInfo.Exists) {
        if (!(bool)w1Top.Force) {
          //ToDo: Log exception
          throw new Exception(message: $"Relative directory for Generated code does not exist (try force=true): {pathToDirectory}");
        }
        else {
          try {
            dirInfo.Create();
          }
          catch (System.IO.IOException e) {
            //ToDo: Log exception
            throw new Exception(message: $"Could not create relative directory for Generated code: {pathToDirectory}", innerException: e);
          }
        }
      }
      // ToDo: Implement a buffering scheme to reduce memory pressure
      var fileInfo = new FileInfo(pathToFile);
      FileStream fileStream;
      if (!fileInfo.Exists) {
        try {
          fileStream = new FileStream(pathToFile, FileMode.Create, FileAccess.Write, FileShare.Write, 0x4000,
            useAsync: false);
        }
        catch (Exception e) {
          Console.WriteLine(e);
          throw;
        }
      }
      else {
        try {
          fileStream = new FileStream(pathToFile, FileMode.Truncate, FileAccess.Write, FileShare.Write, 0x4000,
            useAsync: false);
        }
        catch (Exception e) {
          Console.WriteLine(e);
          throw;
        }
      }
      using (fileStream) {
        string transformedString = sB.ToString(); // ToDo: performance enhancement for large strings and many replacementss?
        foreach (var kvp in gDictionary) {
          transformedString = kvp.Key.Replace(transformedString, kvp.Value);
        }
        var bytes = Encoding.UTF8.GetBytes(transformedString); // ToDo: specify encoding on a per-file basis
        try {
          fileStream.Write(bytes, 0, bytes.Length); // ToDo: implement an async version that is thread-safe for parallel execution
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
