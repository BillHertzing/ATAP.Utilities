using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GPatternReplacement {
    public GPatternReplacement(string? gName = default, Dictionary<Regex,string>? gDictionary = default, GComment? gComment = default) {
      GName = gName == default? "": gName;
      GDictionary = gDictionary == default? new Dictionary<Regex,string>() : gDictionary;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GPatternReplacement>();
    }

    public string? GName { get; }
    public Dictionary<Regex,string> GDictionary;
    public GComment? GComment { get; }
    public Philote<GPatternReplacement> Philote { get; }
  }
}
