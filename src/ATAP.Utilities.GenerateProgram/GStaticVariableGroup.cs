using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
   public class GStaticVariableGroup : IGStaticVariableGroup {
    public GStaticVariableGroup(string gName = default, IDictionary<IPhilote<IGStaticVariable>, IGStaticVariable> gStaticVariables = default) {
      GName = gName == default ? "" : gName;
      GStaticVariables = gStaticVariables == default ? new Dictionary<IPhilote<IGStaticVariable>, IGStaticVariable>() : gStaticVariables;
      Philote = new Philote<IGStaticVariableGroup>();
    }

    public string GName { get; init; }
    public IDictionary<IPhilote<IGStaticVariable>, IGStaticVariable> GStaticVariables { get; init; }
    public IPhilote<IGStaticVariableGroup> Philote { get; init; }
  }
}
