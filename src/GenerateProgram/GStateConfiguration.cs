using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GStateConfiguration  {
    public GStateConfiguration(
      List<string> gStateTransitions = default,
      List<string> gStateConfigurationFluentChains = default)  {
      GStateTransitions = gStateTransitions == default ? new List<string>() : gStateTransitions;
      GStateConfigurationFluentChain = gStateConfigurationFluentChains == default ? new List<string>() : gStateConfigurationFluentChains;
      Philote = new Philote<GStateConfiguration>();
    }
    
    public List<string> GStateTransitions { get; }
    public List<string> GStateConfigurationFluentChain { get; }
    public new Philote<GStateConfiguration> Philote { get; }
  }
}
