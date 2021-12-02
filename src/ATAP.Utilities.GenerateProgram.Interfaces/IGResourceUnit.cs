using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGResourceUnitId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGResourceUnit<TValue> where TValue : notnull {
    string GName { get; init; }
    string GRelativePath { get; init; }
    string GFileSuffix { get; init; }
    Dictionary<IGResourceItemId<TValue>, IGResourceItem<TValue>> GResourceItems { get; init; }
    IGPatternReplacement<TValue> GPatternReplacement { get; init; }
    IGComment<TValue> GComment { get; init; }
    IGResourceUnitId<TValue> Id { get; init; }
  }
}



