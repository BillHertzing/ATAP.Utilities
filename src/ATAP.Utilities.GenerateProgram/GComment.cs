using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GCommentId<TValue> : AbstractStronglyTypedId<TValue>, IGCommentId<TValue> where TValue : notnull {}
  public class GComment<TValue> : IGComment<TValue> where TValue : notnull {
    public GComment(IEnumerable<string> gStatements = default)  {
      GStatements = gStatements == default ? new List<string>() : gStatements;
      Id = new GCommentId<TValue>();
    }

    public IEnumerable<string> GStatements { get; init; }
    public  IGCommentId Id { get; init; }
  }
}






