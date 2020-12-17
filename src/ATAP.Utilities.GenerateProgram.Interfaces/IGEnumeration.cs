using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGEnumeration {
    string GName { get; init; }
    string GUnderlyingBaseType { get; init; }
    string GAccessModifier { get; init; }
    string GVisibility { get; init; }
    string GInheritance { get; init; }
    bool IsBitFlags { get; init; }
    Dictionary<IPhilote<IGEnumerationMember>, IGEnumerationMember> GEnumerationMembers { get; init; }
    Dictionary<IPhilote<IGAttribute>, IGAttribute> GAttributes { get; init; }
    Dictionary<IPhilote<IGAttributeGroup>, IGAttributeGroup> GAttributeGroups { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGEnumeration> Philote { get; init; }
  }
}
