using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GPatternReplacementId<TValue> : AbstractStronglyTypedId<TValue>, IGPatternReplacementId<TValue> where TValue : notnull {}
  public record GPatternReplacement<TValue> : IGPatternReplacement<TValue> where TValue : notnull {
    public GPatternReplacement(string? gName = default, Dictionary<Regex,string>? gDictionary = default, IGComment<TValue>? gComment = default) {
      GName = gName == default? "": gName;
      GDictionary = gDictionary == default? new Dictionary<Regex,string>() : gDictionary;
      GComment = gComment == default? new GComment<TValue>() : gComment;
      Id = new GPatternReplacementId<TValue>();
    }

    public string? GName { get; init; }
    public Dictionary<Regex,string> GDictionary { get; init; }
    public IGComment<TValue>? GComment { get; init; }
    public  IGPatternReplacementId<TValue> Id { get; init; }
  }
}






