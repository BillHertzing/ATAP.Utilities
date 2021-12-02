using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGProjectUnitId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGProjectUnit<TValue> where TValue : notnull {
    string GName { get; init; }
    string GRelativePath { get; init; }
    string GFileSuffix { get; init; }
    Dictionary<IGResourceUnitId<TValue>, IGResourceUnit<TValue>> GResourceUnits { get; init; }
    Dictionary<IGPropertyGroupInProjectUnitId<TValue>, IGPropertyGroupInProjectUnit<TValue>> GPropertyGroupInProjectUnits { get; init; }
    Dictionary<IGItemGroupInProjectUnitId<TValue>, IGItemGroupInProjectUnit<TValue>> GItemGroupInProjectUnits { get; init; }
    IGPatternReplacement<TValue> GPatternReplacement { get; init; }
    IGComment<TValue> GComment { get; init; }
    IGProjectUnitId<TValue> Id { get; init; }
  }
}



