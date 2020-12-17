using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGStaticVariableGroup {
    string GName { get; init; }
    IDictionary<IPhilote<IGStaticVariable>, IGStaticVariable> GStaticVariables { get; init; }
    IPhilote<IGStaticVariableGroup> Philote { get; init; }
  }
}
