using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GPropertyGroupInProjectUnitId<TValue> : AbstractStronglyTypedId<TValue>, IGPropertyGroupInProjectUnitId<TValue> where TValue : notnull {}
  public record GPropertyGroupInProjectUnit<TValue> : IGPropertyGroupInProjectUnit<TValue> where TValue : notnull {
    public GPropertyGroupInProjectUnit(string? gName = default, string? gDescription = default, IList<String>? gPropertyGroupStatements = default) {
      GName = gName == default ? "" : gName;
      GDescription = gDescription == default ? "" : gDescription;
      GPropertyGroupStatements = gPropertyGroupStatements == default ? new List<String>() : gPropertyGroupStatements;
      Id = new GPropertyGroupInProjectUnitId<TValue>();
    }
    public string? GName { get; init; }
    public string? GDescription { get; init; }
    public IList<String>? GPropertyGroupStatements { get; init; }
    public  IGPropertyGroupInProjectUnitId<TValue> Id { get; init; }

  }
}






