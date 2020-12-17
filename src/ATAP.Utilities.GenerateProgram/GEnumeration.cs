using System;
using System.Collections.Generic;
//using System.Management.Instrumentation;
using ATAP.Utilities.Philote;


namespace ATAP.Utilities.GenerateProgram {
  
  public class GEnumeration : IGEnumeration {
    public GEnumeration(string gName = default, string gUnderlyingBaseType = default, string gVisibility = default, string gInheritance = default,
      bool isBitFlags = default,
      Dictionary<IPhilote<IGEnumerationMember>, IGEnumerationMember> gEnumerationMembers = default,
      Dictionary<IPhilote<IGAttribute>, IGAttribute> gAttributes = default,
      Dictionary<IPhilote<IGAttributeGroup>, IGAttributeGroup> gAttributeGroups = default,
      GComment gComment = default
      ) {
      GName = gName == default ? "" : gName;
      GUnderlyingBaseType = gUnderlyingBaseType == default ? "" : gUnderlyingBaseType;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GInheritance = gInheritance == default ? "" : gInheritance; ;
      IsBitFlags = isBitFlags == default ? false : (bool)isBitFlags;
      GEnumerationMembers = gEnumerationMembers == default ? new Dictionary<IPhilote<IGEnumerationMember>, IGEnumerationMember>() : gEnumerationMembers;
      GAttributes = gAttributes == default ? new Dictionary<IPhilote<IGAttribute>, IGAttribute>() : gAttributes;
      GAttributeGroups = gAttributeGroups == default ? new Dictionary<IPhilote<IGAttributeGroup>, IGAttributeGroup>() : gAttributeGroups;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<IGEnumeration>();
    }
    public string GName { get; init; }
    public string GUnderlyingBaseType { get; init; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; init; }
    public string GVisibility { get; init; }
    public string GInheritance { get; init; }
    public bool IsBitFlags { get; init; }
    public Dictionary<IPhilote<IGEnumerationMember>, IGEnumerationMember> GEnumerationMembers { get; init; }
    public Dictionary<IPhilote<IGAttribute>, IGAttribute> GAttributes { get; init; }
    public Dictionary<IPhilote<IGAttributeGroup>, IGAttributeGroup> GAttributeGroups { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGEnumeration> Philote { get; init; }

  }
}
