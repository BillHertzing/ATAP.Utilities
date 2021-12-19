using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GBodyId<TValue> : AbstractStronglyTypedId<TValue>, IGBodyId<TValue> where TValue : notnull {}
  public class GBody<TValue> : IGBody<TValue> where TValue : notnull {
    public GBody(IList<string> gStatements = default, IGComment<TValue> gComment = default
    ) {
      GStatements = gStatements == default ? new List<string>() : gStatements;
      GComment = gComment == default ? new GComment<TValue>() : gComment;
      Id = new GBodyId<TValue>();
    }
    public IGComment<TValue> GComment { get; init; }
    public IList<string> GStatements { get; init; }
    public  IGBodyId<TValue> Id { get; init; }
  }
}






