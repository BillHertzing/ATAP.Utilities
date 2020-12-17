using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGEnumerationGroup {
    string GName { get; init; }
    IDictionary<IPhilote<IGEnumeration>, IGEnumeration> GEnumerations { get; init; }
    IPhilote<IGEnumerationGroup> Philote { get; init; }
  }
}
