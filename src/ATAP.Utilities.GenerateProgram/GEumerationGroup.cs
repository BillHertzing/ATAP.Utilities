using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GEnumerationGroup : IGEnumerationGroup {
    public GEnumerationGroup(string gName = default, IDictionary<IPhilote<IGEnumeration>, IGEnumeration> gEnumerations = default) {
      GName = gName == default ? "" : gName;
      GEnumerations = gEnumerations == default ? new Dictionary<IPhilote<IGEnumeration>, IGEnumeration>() : gEnumerations;
      Philote = new Philote<IGEnumerationGroup>();
    }

    public string GName { get; init; }
    public IDictionary<IPhilote<IGEnumeration>, IGEnumeration> GEnumerations { get; init; }
    public IPhilote<IGEnumerationGroup> Philote { get; init; }
  }
}
