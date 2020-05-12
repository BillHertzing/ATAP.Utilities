using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.StringConstants;
//using AutoMapper.Configuration;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GUsingGroupExtensions;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblyGroup MConsoleSource(
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default
      ) {
      var gAssemblyGroupName = "ConsoleSource";

      var gAssemblyGroup = GAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespace, true);

      // Modify it

      return gAssemblyGroup;
    }
  }
}
