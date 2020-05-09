using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GAttributeGroup {
    public GAttributeGroup(string gName = "", Dictionary<Philote<GAttribute>, GAttribute> gAttributes = default,
      GComment gComment = default
    ) {
      GName = gName;
      GAttributes = gAttributes == default ? new Dictionary<Philote<GAttribute>, GAttribute>() : gAttributes;
      GComment = gComment == default ? new GComment() : gComment;

      Philote = new Philote<GAttributeGroup>();
    }
    public string GName { get; }
    public Dictionary<Philote<GAttribute>, GAttribute> GAttributes { get; }
    public GComment GComment { get; }
    public Philote<GAttributeGroup> Philote { get; }
  }
}
