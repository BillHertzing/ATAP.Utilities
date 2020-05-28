using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyUnitExtensions;
using static GenerateProgram.GCompilationUnitExtensions;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static GenerateProgram.StringConstants;
//using AutoMapper.Configuration;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GUsingGroupExtensions;
using static GenerateProgram.GMacroExtensions;
using static GenerateProgram.GArgumentExtensions;
using static GenerateProgram.Lookup;

namespace GenerateProgram {
  public static partial class GAssemblyGroupExtensions {
    public static GAssemblyGroup MAssemblyGroupGHBSConstructor(string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default,
      GPatternReplacement gPatternReplacement = default) {

      var part1Tuple = MAssemblyGroupCommonConstructorForGHHSAndGHBSPart1(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespace, gPatternReplacement);
 
      #region Titular Base Class (IHostedService)
      var gClass = new GClass(part1Tuple.gCompilationUnitName, gVisibility: "public",
        gImplements: new List<string> { "IHostedService", "IDisposable" },
        gDisposesOf: new List<string> { "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle" });
      #region specific methods for BackgroundService
      gClass.AddMethod(CreateExecuteAsyncMethod(gAccessModifier: "override async"));
      gClass.AddMethodGroup(CreateStartStopAsyncMethods(gAccessModifier: "override async"));
      #endregion
      #endregion
      var gAssemblyGroup = MAssemblyGroupCommonConstructorForGHHSAndGHBSPart2(part1Tuple, gClass);

      return gAssemblyGroup;
    }
    public static void GAssemblyGroupGHBSFinalizer(GAssemblyGroup gAssemblyGroup) {
      //#region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor
      //var titularBaseClassName = $"{gAssemblyGroup.GName}Base";
      //var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularBaseClassName) ;
      //#endregion
      //#region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
      //var titularClassName = $"{gAssemblyGroup.GName}";
      //var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularClassName) ;
      //#endregion
      // No Additional work needed, call CommonFinalizer
      GAssemblyGroupCommonFinalizer(gAssemblyGroup);
    }
  }
}
