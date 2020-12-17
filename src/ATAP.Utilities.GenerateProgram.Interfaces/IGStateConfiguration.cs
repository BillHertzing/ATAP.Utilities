using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGStateConfiguration {
    IList<string> GStateNames { get; init; }
    IList<string> GTriggerNames { get; init; }
    IList<(string state, string trigger, string nextstate, string predicate)> GDiGraphStates { get; init; }
    IList<string> GDOTGraphStatements { get; init; }
    IPhilote<IGStateConfiguration> Philote { get; init; }
  }
}
