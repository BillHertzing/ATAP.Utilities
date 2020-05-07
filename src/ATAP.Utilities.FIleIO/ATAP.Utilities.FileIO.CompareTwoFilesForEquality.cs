using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;


namespace ATAP.Utilities.FileIO {
  public static partial class Extensions {
    /// <summary>
    /// ReadOnlySpan
    /// </summary>
    /// <param name="file1"></param>
    /// <param name="file2"></param>
    /// <returns>bool</returns>
    /// Attribution to: https://developpaper.com/the-fastest-way-to-compare-the-contents-of-two-files-in-net-core/
    private static bool CompareByReadOnlySpan(string file1, string file2) {
      // ToDo: Need improvements to handle arbitrary size files, and needs an async version
      // ToDo: currently broke because it can't resolve ReadOnlySpan<>
      const int BYTES_TO_READ = 0x4000;

      using (FileStream fs1 = File.Open(file1, FileMode.Open))
      using (FileStream fs2 = File.Open(file2, FileMode.Open)) {
        byte[] one = new byte[BYTES_TO_READ];
        byte[] two = new byte[BYTES_TO_READ];
        while (true) {
          int len1 = fs1.Read(one, 0, BYTES_TO_READ);
          int len2 = fs2.Read(two, 0, BYTES_TO_READ);
          if (len1 != len2) return false;
          if (len1 == 0 && len2 == 0) break; // Both files are read to the end and exit the while loop
          // Byte arrays can be converted directly to ReadOnlySpan
          //if (!((ReadOnlySpan<byte>)one).SequenceEqual((ReadOnlySpan<byte>)two)) return false;

          //
        }
      }

      return true;
    }
  }
}
