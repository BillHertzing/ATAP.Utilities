using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GAssemblyGroup {
    public GAssemblyGroup(string gName = "", string? gDescription = default, string? gRelativePath = default, Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit> gAssemblyUnits = default
    ) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GDescription = gDescription == default ? "" : gDescription;
      GRelativePath = gRelativePath == default ? "" : gRelativePath;
      GAssemblyUnits = gAssemblyUnits == default ? new Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit>() : gAssemblyUnits;
      Philote = new Philote<GAssemblyGroup>();
    }
    public string GName { get; }
    public string GDescription { get; }
    public string? GRelativePath { get; }
    public Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit>? GAssemblyUnits { get; }
    public Philote<GAssemblyGroup> Philote { get; }

  }
}
