using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public class GAssemblyGroup : IGAssemblyGroup {
    public GAssemblyGroup(string gName = "", string gDescription = "", string gRelativePath = "",
      Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit> gAssemblyUnits = default,
      GPatternReplacement gPatternReplacement = default,
      GComment gComment = default
    ) {
      GName = gName;
      GDescription = gDescription;
      GRelativePath = gRelativePath;
      GAssemblyUnits = gAssemblyUnits == default ? new Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit>() : gAssemblyUnits;
      GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GComment = gComment == default ? new GComment() : gComment;

      Philote = new Philote<GAssemblyGroup>();
    }
    public string GName { get; }
    public string GDescription { get; }
    public string GRelativePath { get; }
    public Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit>? GAssemblyUnits { get; }
    public GPatternReplacement GPatternReplacement { get; }
    public GComment GComment { get; }
    public Philote<GAssemblyGroup> Philote { get; }

  }
}
