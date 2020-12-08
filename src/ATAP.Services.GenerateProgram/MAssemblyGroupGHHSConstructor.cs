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
  public static partial class GMacroExtensions {
    public static GAssemblyGroupBasicConstructorResult MAssemblyGroupGHHSConstructor(string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      var gAssemblyGroupBasicConstructorResult = MAssemblyGroupCommonConstructorForGHHSAndGHBS(gAssemblyGroupName,
        subDirectoryForGeneratedFiles,
        baseNamespaceName, gPatternReplacement);

      #region Additions to Titular Base Class (IBackgroundService)
      #region specific methods for IHostedService
      gAssemblyGroupBasicConstructorResult.gClassBase.AddMethodGroup(MCreateStartStopAsyncMethods(gAccessModifier: "virtual async"));
      #endregion
      #endregion
      MAssemblyGroupCommonConstructorForGHHSAndGHBSPart2(gAssemblyGroupBasicConstructorResult);
      return gAssemblyGroupBasicConstructorResult;
    }
    public static void GAssemblyGroupGHHSFinalizer(GAssemblyGroupBasicConstructorResult gAssemblyGroupBasicConstructorResult) {
      //#region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor
      //var titularBaseClassName = $"{gAssemblyGroup.GName}Base";
      //var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>() {gAssemblyGroup}, gClassName: titularBaseClassName);
      //var gClassBase = titularAssemblyUnitLookupPrimaryConstructorResults.gClasss.First();
      //#endregion
      //#region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
      //var titularClassName = $"{gAssemblyGroup.GName}";
      //var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<GAssemblyGroup>() {gAssemblyGroup}, gClassName: titularClassName);
      //var gClassDerived = titularAssemblyUnitLookupDerivedClassResults.gClasss.First();
      //#endregion
      //#region Lookup the Interfaces
      //var titularInterfaceDerivedName = $"I{gAssemblyGroup.GName}";
      //var titularAssemblyUnitLookupDerivedInterfacesResults = LookupInterfaces(new List<GAssemblyGroup>() {gAssemblyGroup}, gInterfaceName: titularInterfaceDerivedName);
      //var gInterfaceDerived = titularAssemblyUnitLookupDerivedInterfacesResults.gInterfaces.First();
      //var titularInterfaceBaseName = $"I{gAssemblyGroup.GName}";
      //var titularAssemblyUnitLookupBaseInterfacesResults = LookupInterfaces(new List<GAssemblyGroup>() {gAssemblyGroup}, gInterfaceName: titularInterfaceBaseName);
      //var gInterfaceBase = titularAssemblyUnitLookupBaseInterfacesResults.gInterfaces.First();
      //#endregion
     // No Additional work needed, call CommonFinalizer
      GAssemblyGroupCommonFinalizer(gAssemblyGroupBasicConstructorResult);
    }

    //public static void GAssemblyGroupGHHSFinalizer( GAssemblyGroup gAssemblyGroup,  GClass gClassDerived, GClass gClassBase, GInterface gInterfaceDerived, GInterface gInterfaceBase) {
    //  //#region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor
    //  //var titularBaseClassName = $"{gAssemblyGroup.GName}Base";
    //  //var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularBaseClassName) ;
    //  //#endregion
    //  //#region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
    //  //var titularClassName = $"{gAssemblyGroup.GName}";
    //  //var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularClassName) ;
    //  //#endregion
    //  // No Additional work needed, call CommonFinalizer
    //  GAssemblyGroupCommonFinalizer(gAssemblyGroup,  gClassDerived, gClassBase,  gInterfaceDerived,  gInterfaceBase);
    //}

  }
}
