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
    public static GAssemblyGroupBasicConstructorResult MAssemblyGroupGHBSConstructor(string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default, bool hasInterfaces = true,
      GPatternReplacement gPatternReplacement = default) {
      var gCreateAssemblyGroupResult = MAssemblyGroupGHHSConstructor(gAssemblyGroupName,
        subDirectoryForGeneratedFiles,
        baseNamespace, hasInterfaces, gPatternReplacement);

      #region Additions to Titular Base Class (IBackgroundService)
      #region specific methods for BackgroundService
      gCreateAssemblyGroupResult.gClassBase.AddMethod(MCreateExecuteAsyncMethod(gAccessModifier: "override async"));
      gCreateAssemblyGroupResult.gClassBase.AddMethodGroup(MCreateStartStopAsyncMethods(gAccessModifier: "override async"));
      #endregion
      #endregion
      MAssemblyGroupCommonConstructorForGHHSAndGHBSPart2(gCreateAssemblyGroupResult);

      return gCreateAssemblyGroupResult;
    }
    public static void GAssemblyGroupGHBSFinalizer(GAssemblyGroupBasicConstructorResult mCreateAssemblyGroupResult) {
      //#region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor
      //var titularBaseClassName = $"{gAssemblyGroup.GName}Base";
      //var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularBaseClassName) ;
      //#endregion
      //#region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
      //var titularClassName = $"{gAssemblyGroup.GName}";
      //var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularClassName) ;
      //#endregion
      // No Additional work needed, call CommonFinalizer
      GAssemblyGroupCommonFinalizer(mCreateAssemblyGroupResult);
    }
  }
}
