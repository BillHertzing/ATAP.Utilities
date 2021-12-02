using System.Collections.Generic;
using System.Text.RegularExpressions;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram
{


  public interface IGPatternReplacementId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGPatternReplacement<TValue> where TValue : notnull {
    string? GName { get; init; }
    Dictionary<Regex, string> GDictionary { get; init; }
    IGComment<TValue>? GComment { get; init; }
    IGPatternReplacementId<TValue> Id { get; init; }
  }
}



