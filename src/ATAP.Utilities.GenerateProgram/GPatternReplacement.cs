using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public record GPatternReplacement : IGPatternReplacement {
    public GPatternReplacement(string? gName = default, Dictionary<Regex,string>? gDictionary = default, IGComment? gComment = default) {
      GName = gName == default? "": gName;
      GDictionary = gDictionary == default? new Dictionary<Regex,string>() : gDictionary;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<IGPatternReplacement>();
    }

    public string? GName { get; init; }
    public Dictionary<Regex,string> GDictionary { get; init; }
    public IGComment? GComment { get; init; }
    public IPhilote<IGPatternReplacement> Philote { get; init; }
  }
}
