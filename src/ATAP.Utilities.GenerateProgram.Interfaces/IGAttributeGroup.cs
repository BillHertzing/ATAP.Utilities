using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGAttributeGroup {
    string GName { get; init; }
    Dictionary<IPhilote<IGAttribute>, IGAttribute> GAttributes { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGAttributeGroup> Philote { get; init; }
  }
}

