using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGAssemblyUnitSignilId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGAssemblyUnitSignil<TValue> where TValue : notnull {
    string GName { get; init; }
    // ToDo:  Add GDescription to the AssemblyUnit
    string GRelativePath { get; init; }
    IGProjectUnit<TValue> GProjectUnit { get; init; }
    IDictionary<IGCompilationUnitId<TValue>, IGCompilationUnit<TValue>> GCompilationUnits { get; init; }
    IDictionary<IGPropertiesUnitId<TValue>, IGPropertiesUnit<TValue>> GPropertiesUnits { get; init; }
    IDictionary<IGResourceUnitId<TValue>, IGResourceUnit<TValue>> GResourceUnits { get; init; }
    IGPatternReplacement<TValue> GPatternReplacement { get; init; }
    IGComment<TValue> GComment { get; init; }
    IGAssemblyUnitSignilId<TValue> Id { get; init; }
  }
}



