using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GStateConfiguration  {
    public GStateConfiguration(
      List<string> gStateNames = default,
      List<string> gTriggerNames = default,
      List<(string gtate,string trigger, string nextstate, string predicate)> gDiGraphStates = default,
      List<string> gDOTGraphStatements = default
      )  {
      GStateNames = gStateNames == default ? new List<string>() : gStateNames;
      GTriggerNames = gTriggerNames == default ? new List<string>() : gTriggerNames;
      GDiGraphStates = gDiGraphStates == default ? new List<(string gtate,string trigger, string nextstate, string predicate)>() : gDiGraphStates;
      GDOTGraphStatements = gDOTGraphStatements == default ? new List<string>() : gDOTGraphStatements;
      Philote = new Philote<GStateConfiguration>();
    }
    
    public List<string> GStateNames { get; }
    public List<string> GTriggerNames { get; }
    public List<(string state,string trigger, string nextstate, string predicate)> GDiGraphStates { get; }
    public List<string> GDOTGraphStatements { get; }
    public new Philote<GStateConfiguration> Philote { get; }
  }
}
