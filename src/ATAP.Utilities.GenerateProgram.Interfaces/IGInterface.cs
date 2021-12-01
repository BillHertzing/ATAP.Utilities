using System;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGInterface {
    string GName { get; }
    string GVisibility { get; }
    string GAccessModifier { get; }
    string GInheritance { get; }
    IList<string> GImplements { get; }
    IDictionary<IPhilote<IGProperty>, IGProperty> GPropertys { get; }
    IDictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> GPropertyGroups { get; }
    IDictionary<IPhilote<IGMethod>, IGMethod> GMethods { get; }
    IDictionary<IPhilote<IGMethodGroup>, IGMethodGroup> GMethodGroups { get; }
    IPhilote<IGInterface> Philote { get; }
  }
}

