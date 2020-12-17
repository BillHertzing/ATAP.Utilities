using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static ATAP.Utilities.GenerateProgram.GAssemblyUnitExtensions;
using static ATAP.Utilities.GenerateProgram.GCompilationUnitExtensions;
using static ATAP.Utilities.GenerateProgram.GItemGroupInProjectUnitExtensions;
using static ATAP.Utilities.GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static ATAP.Utilities.GenerateProgram.StringConstants;
//using AutoMapper.Configuration;
using static ATAP.Utilities.GenerateProgram.GMethodGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GMethodExtensions;
using static ATAP.Utilities.GenerateProgram.GUsingGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GMacroExtensions;
using static ATAP.Utilities.GenerateProgram.GArgumentExtensions;
using static ATAP.Utilities.GenerateProgram.Lookup;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GAssemblyGroupExtensions {
    public static IGAssemblyGroupBasicConstructorResult MAssemblyGroupGHBSConstructor(string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default, bool hasInterfaces = true,
      IGPatternReplacement gPatternReplacement = default) {
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
    public static void GAssemblyGroupGHBSFinalizer(IGAssemblyGroupBasicConstructorResult mCreateAssemblyGroupResult) {
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
