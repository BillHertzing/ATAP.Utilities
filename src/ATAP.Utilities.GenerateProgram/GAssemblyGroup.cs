using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public class GAssemblyGroup : IGAssemblyGroup {
    public GAssemblyGroup(string gName = "", string gDescription = "", string gRelativePath = "",

      IDictionary<IPhilote<IGAssemblyUnit>, IGAssemblyUnit> gAssemblyUnits = default,
      IGPatternReplacement gPatternReplacement = default,
      IGComment gComment = default
    ) {
      GName = gName;
      GDescription = gDescription;
      GRelativePath = gRelativePath;
      GAssemblyUnits = gAssemblyUnits == default ? new Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit>() : gAssemblyUnits;
      GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GComment = gComment == default ? new GComment() : gComment;

      Philote = new Philote<GAssemblyGroup>();
    }
    public string GName { get; init; }
    public string GDescription { get; init; }
    public string GRelativePath { get; init; }
    public
      IDictionary<IPhilote<IGAssemblyUnit>, IGAssemblyUnit>? GAssemblyUnits { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGAssemblyGroup> Philote { get; init; }

  }
}
