using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGStateConfigurationId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGStateConfiguration<TValue> where TValue : notnull {
    IList<string> GStateNames { get; init; }
    IList<string> GTriggerNames { get; init; }
    IList<(string state, string trigger, string nextstate, string predicate)> GDiGraphStates { get; init; }
    IList<string> GDOTGraphStatements { get; init; }
    IGStateConfigurationId<TValue> Id { get; init; }
  }
}


