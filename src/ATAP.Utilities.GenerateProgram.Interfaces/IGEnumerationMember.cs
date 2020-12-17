using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGEnumerationMember {
    string GName { get; init; }
    int? GValue { get; init; }
    IDictionary<IPhilote<IGAttribute>, IGAttribute> GAttributes { get; init; }
    IDictionary<IPhilote<IGAttributeGroup>, IGAttributeGroup> GAttributeGroups { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGEnumerationMember> Philote { get; init; }
  }
}
