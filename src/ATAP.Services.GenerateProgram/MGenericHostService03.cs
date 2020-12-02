using System;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GUsingGroupExtensions;
using static GenerateProgram.GAttributeGroupExtensions;
using static GenerateProgram.Lookup;
//using AutoMapper.Configuration;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblySingle MGenericHostService03(string gAssemblySingleName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default) {
      return MGenericHostService03(gAssemblySingleName, subDirectoryForGeneratedFiles, baseNamespaceName, new GPatternReplacement()  );
    }
    public static GAssemblySingle MGenericHostService03(string gAssemblySingleName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      var mCreateAssemblySingleResult = MGenericHostService(gAssemblySingleName, subDirectoryForGeneratedFiles,
        baseNamespaceName, _gPatternReplacement);
      return mCreateAssemblySingleResult.gAssemblySingle;
    }
  }
}
