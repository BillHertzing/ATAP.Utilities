using System;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GItemGroupInProjectUnitId<TValue> : AbstractStronglyTypedId<TValue>, IGItemGroupInProjectUnitId<TValue> where TValue : notnull {}
  public class GItemGroupInProjectUnit<TValue> : IGItemGroupInProjectUnit<TValue> where TValue : notnull {
    public GItemGroupInProjectUnit(string gName = "", string gDescription = "", IGBody gBody = default, IGComment gComment = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GDescription = gDescription == default ? "" : gDescription;
      GBody = gBody == default ? new GBody() : gBody;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GItemGroupInProjectUnitId<TValue>();
    }
    public string GName { get; init; }
    public string GDescription { get; init; }
    public IGBody GBody { get; init; }
    public IGComment GComment { get; init; }
    public  IGItemGroupInProjectUnitId Id { get; init; }

  }
}






