using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
   public class GStateConfiguration : IGStateConfiguration {
    public GStateConfiguration(
      IList<string> gStateNames = default,
      IList<string> gTriggerNames = default,
      IList<(string gtate, string trigger, string nextstate, string predicate)> gDiGraphStates = default,
      IList<string> gDOTGraphStatements = default
      ) {
      GStateNames = gStateNames == default ? new List<string>() : gStateNames;
      GTriggerNames = gTriggerNames == default ? new List<string>() : gTriggerNames;
      GDiGraphStates = gDiGraphStates == default ? new List<(string gtate, string trigger, string nextstate, string predicate)>() : gDiGraphStates;
      GDOTGraphStatements = gDOTGraphStatements == default ? new List<string>() : gDOTGraphStatements;
      Philote = new Philote<GStateConfiguration>();
    }

    public IList<string> GStateNames { get; init; }
    public IList<string> GTriggerNames { get; init; }
    public IList<(string state, string trigger, string nextstate, string predicate)> GDiGraphStates { get; init; }
    public IList<string> GDOTGraphStatements { get; init; }
    public new IPhilote<IGStateConfiguration> Philote { get; init; }
  }
}
