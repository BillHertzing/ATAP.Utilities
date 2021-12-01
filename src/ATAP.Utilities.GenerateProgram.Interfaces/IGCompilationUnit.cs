using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGCompilationUnit {
    string GName { get; init; }
    Dictionary<IPhilote<IGUsingGroup>, IGUsingGroup> GUsingGroups { get; init; }
    Dictionary<IPhilote<IGUsing>, IGUsing> GUsings { get; init; }
    Dictionary<IPhilote<IGNamespace>, IGNamespace> GNamespaces { get; init; }
    string GRelativePath { get; init; }
    string GFileSuffix { get; init; }
    IGPatternReplacement GPatternReplacement { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGCompilationUnit> Philote { get; init; }
  }
}

