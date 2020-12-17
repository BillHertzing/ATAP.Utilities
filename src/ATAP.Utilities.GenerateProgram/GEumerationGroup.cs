using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GEnumerationGroup : IGEnumerationGroup {
    public GEnumerationGroup(string gName = default, Dictionary<IPhilote<IGEnumeration>, IGEnumeration> gEnumerations = default) {
      GName = gName == default ? "" : gName;
      GEnumerations = gEnumerations == default ? new Dictionary<Philote<GEnumeration>, GEnumeration>() : gEnumerations;
      Philote = new Philote<GEnumerationGroup>();
    }

    public string GName { get; init; }
    public Dictionary<IPhilote<IGEnumeration>, IGEnumeration> GEnumerations { get; init; }
    public IPhilote<IGEnumerationGroup> Philote { get; init; }
  }
}
