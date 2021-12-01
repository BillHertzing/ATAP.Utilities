using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGEnumerationGroup {
    string GName { get; init; }
    IDictionary<IPhilote<IGEnumeration>, IGEnumeration> GEnumerations { get; init; }
    IPhilote<IGEnumerationGroup> Philote { get; init; }
  }
}

