using System.Collections.Generic;
using System.Text.RegularExpressions;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram
{
  public interface IGPatternReplacement
  {
    string? GName { get; init; }
    Dictionary<Regex, string> GDictionary { get; init; }
    IGComment? GComment { get; init; }
    IPhilote<IGPatternReplacement> Philote { get; init; }
  }
}

