using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GAssemblyUnit : IGAssemblyUnit {
    public GAssemblyUnit(string gName = default, string gRelativePath = default,
      GProjectUnit gProjectUnit = default,
      Dictionary<Philote<GCompilationUnit>, GCompilationUnit> gCompilationUnits = default,
      Dictionary<Philote<GPropertiesUnit>, GPropertiesUnit> gPropertiesUnits = default,
      Dictionary<Philote<GResourceUnit>, GResourceUnit> gResourceUnits = default,
      GPatternReplacement gPatternReplacement = default,
      GComment gComment = default
    ) {
      GName = gName == default ? "" : gName;
      GRelativePath = gRelativePath == default ? "" : gRelativePath;
      GProjectUnit = gProjectUnit == default? new GProjectUnit(GName) : gProjectUnit;
      GCompilationUnits = gCompilationUnits == default ? new Dictionary<Philote<GCompilationUnit>, GCompilationUnit>() : gCompilationUnits;
      GPropertiesUnits = gPropertiesUnits == default ? new Dictionary<Philote<GPropertiesUnit>, GPropertiesUnit>() : gPropertiesUnits;
      GResourceUnits = gResourceUnits == default ? new Dictionary<Philote<GResourceUnit>, GResourceUnit>() : gResourceUnits;
      GComment = gComment == default? new GComment() : gComment;
      GPatternReplacement = gPatternReplacement == default? new GPatternReplacement() : gPatternReplacement;
      Philote = new Philote<GAssemblyUnit>();
    }

    public string GName { get; }
    public string GRelativePath { get; }
    public GProjectUnit GProjectUnit { get; }
    public Dictionary<Philote<GCompilationUnit>, GCompilationUnit> GCompilationUnits { get; }
    public Dictionary<Philote<GPropertiesUnit>, GPropertiesUnit> GPropertiesUnits { get; }
    public Dictionary<Philote<GResourceUnit>, GResourceUnit> GResourceUnits { get; }
    public GPatternReplacement GPatternReplacement { get; }
    public GComment GComment { get; }
    public Philote<GAssemblyUnit> Philote { get; }

  }
}
