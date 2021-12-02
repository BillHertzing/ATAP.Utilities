using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram
{


  public interface IGAssemblyGroupId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGAssemblyGroup<TValue> where TValue : notnull {
    string GName { get; init; }
    string GDescription { get; init; }
    string GRelativePath { get; init; }
    IDictionary<IGAssemblyUnitId<TValue>, IGAssemblyUnit<TValue>> GAssemblyUnits { get; init; }
    IGPatternReplacement<TValue> GPatternReplacement { get; init; }
    IGComment<TValue> GComment { get; init; }
    IGAssemblyGroupId<TValue> Id { get; init; }
  }
}



