using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class Extensions {
    // https://stackoverflow.com/questions/8809354/replace-first-occurrence-of-pattern-in-a-string
    public static string ReplaceFirst(this string text, string search, string replace) {
      int pos = text.IndexOf(search);
      if (pos < 0) {
        return text;
      }
      return text.Substring(0, pos) + replace + text.Substring(pos + search.Length);
    }

    public static StringBuilder ReplaceFirst(this StringBuilder text, string search, string replace) {
     var t = text.ToString().ReplaceFirst(search, replace);
     return text.Clear().Append(t);
    }

    public static string ToUpperFirstChar(this string text) {
      if (text.Length == 1) {
        return char.ToUpper(text[0]).ToString();
      }
      else {
        return char.ToUpper(text[0]) + text.Substring(1);
      }
    }
    public static string ToLowerFirstChar(this string text) {
      if (text.Length == 1) {
        return char.ToLower(text[0]).ToString();
      }
      else {
        return char.ToLower(text[0]) + text.Substring(1);
      }
    }
  }

}
