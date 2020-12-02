using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GEnumerationMember {
    public GEnumerationMember(string gName = "", int? gValue = default,

      Dictionary<Philote<GAttribute>, GAttribute> gAttributes = default,
      Dictionary<Philote<GAttributeGroup>, GAttributeGroup> gAttributeGroups = default,
      GComment gComment = default
      ) {
      GName = gName;
      GValue = gValue;
      GAttributes = gAttributes == default ? new Dictionary<Philote<GAttribute>, GAttribute>() : gAttributes;
      GAttributeGroups = gAttributeGroups == default ? new Dictionary<Philote<GAttributeGroup>, GAttributeGroup>() : gAttributeGroups;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GEnumerationMember>();
    }

    public string GName { get;  }
    // ToDo: support for enumeration member types other than int
    public int? GValue { get; }
    public Dictionary<Philote<GAttribute>, GAttribute> GAttributes { get; }
    public Dictionary<Philote<GAttributeGroup>, GAttributeGroup> GAttributeGroups { get; }
    public GComment GComment { get; }
    public Philote<GEnumerationMember> Philote { get; }

  }
}

