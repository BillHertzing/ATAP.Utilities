using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGCompilationUnitId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGCompilationUnit<TValue> where TValue : notnull {
    string GName { get; init; }
    Dictionary<IGUsingGroupId<TValue>, IGUsingGroup<TValue>> GUsingGroups { get; init; }
    Dictionary<IGUsingId<TValue>, IGUsing<TValue>> GUsings { get; init; }
    Dictionary<IGNamespaceId<TValue>, IGNamespace<TValue>> GNamespaces { get; init; }
    string GRelativePath { get; init; }
    string GFileSuffix { get; init; }
    IGPatternReplacement<TValue> GPatternReplacement { get; init; }
    IGComment<TValue> GComment { get; init; }
    IGCompilationUnitId<TValue> Id { get; init; }
  }
}



