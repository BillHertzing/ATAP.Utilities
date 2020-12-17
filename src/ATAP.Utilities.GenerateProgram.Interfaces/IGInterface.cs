using System;
using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGInterface {
    string GName { get; }
    string GVisibility { get; }
    string GAccessModifier { get; }
    string GInheritance { get; }
    IList<string> GImplements { get; }
    Dictionary<IPhilote<IGProperty>, IGProperty> GPropertys { get; }
    Dictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> GPropertyGroups { get; }
    Dictionary<IPhilote<IGMethod>, IGMethod> GMethods { get; }
    Dictionary<IPhilote<IGMethodGroup>, IGMethodGroup> GMethodGroups { get; }
    IPhilote<IGInterface> Philote { get; }
  }
}
