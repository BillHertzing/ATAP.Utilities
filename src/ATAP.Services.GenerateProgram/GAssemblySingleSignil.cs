using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram
{
    public class GAssemblySingleSignil
    {
        public GAssemblySingleSignil(string gName = default, string gDescription = default, string gRelativePath = default,
          Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit> gAssemblyUnits = default,
          GPatternReplacement gPatternReplacement = default, GComment gComment = default)
        {
            GName = gName == default ? "" : gName;
            GDescription = gDescription == default ? "" : gDescription;
            GRelativePath = gRelativePath == default ? "" : gRelativePath;
            GAssemblyUnits = gAssemblyUnits == default ? new Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit>() : gAssemblyUnits;
            GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
            GComment = gComment == default ? new GComment() : gComment;
        }
        public string GName { get; }
        public string GDescription { get; }
        public string GRelativePath { get; }
        public Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit> GAssemblyUnits { get; }
        public GPatternReplacement GPatternReplacement { get; }
        public GComment GComment { get; }
    }
}
