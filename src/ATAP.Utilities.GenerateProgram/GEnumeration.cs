using System;
using System.Collections.Generic;
//using System.Management.Instrumentation;
using ATAP.Utilities.Philote;


namespace GenerateProgram {
  public class GEnumeration {
    public GEnumeration(string gName = default, string gUnderlyingBaseType = default, string gVisibility = default,  string gInheritance = default,
      bool isBitFlags = default,
      Dictionary<Philote<GEnumerationMember>, GEnumerationMember> gEnumerationMembers = default,
      Dictionary<Philote<GAttribute>, GAttribute> gAttributes = default,
      Dictionary<Philote<GAttributeGroup>, GAttributeGroup> gAttributeGroups = default,
      GComment gComment = default
      ) {
      GName = gName == default ? "" : gName;
      GUnderlyingBaseType = gUnderlyingBaseType == default ? "" : gUnderlyingBaseType;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GInheritance = gInheritance == default ? "" : gInheritance;;
      IsBitFlags = isBitFlags == default ? false : (bool) isBitFlags;
      GEnumerationMembers = gEnumerationMembers == default ? new Dictionary<Philote<GEnumerationMember>, GEnumerationMember>() : gEnumerationMembers;
      GAttributes = gAttributes == default ? new Dictionary<Philote<GAttribute>, GAttribute>() : gAttributes;
      GAttributeGroups = gAttributeGroups == default ? new Dictionary<Philote<GAttributeGroup>, GAttributeGroup>() : gAttributeGroups;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GEnumeration>();
    }
    public string GName { get; }
    public string GUnderlyingBaseType { get; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; }
    public string GVisibility { get; }
    public string GInheritance { get; }
    public bool IsBitFlags { get; }
    public Dictionary<Philote<GEnumerationMember>, GEnumerationMember> GEnumerationMembers { get; }
    public Dictionary<Philote<GAttribute>, GAttribute> GAttributes { get; }
    public Dictionary<Philote<GAttributeGroup>, GAttributeGroup> GAttributeGroups { get; }
    public GComment GComment { get; }
    public Philote<GEnumeration> Philote { get; }

  }
}
