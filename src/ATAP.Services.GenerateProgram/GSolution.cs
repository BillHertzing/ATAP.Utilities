using System;

namespace ATAP.Services.GenerateProgram
{
    public class GSolution
    {

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


    }
}
