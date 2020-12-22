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
  public static partial class GMacroExtensions {
    public static IGAssemblyGroupBasicConstructorResult MAssemblyGroupGHHSConstructor(string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,bool hasInterfaces = true,
      IGPatternReplacement gPatternReplacement = default) {
      var gAssemblyGroupBasicConstructorResult = MAssemblyGroupCommonConstructorForGHHSAndGHBS(gAssemblyGroupName,
        subDirectoryForGeneratedFiles,
        baseNamespaceName, hasInterfaces, gPatternReplacement);

      #region Additions to Titular Base Class (IBackgroundService)
      #region specific methods for IHostedService
      gAssemblyGroupBasicConstructorResult.GClassBase.AddMethodGroup(MCreateStartStopAsyncMethods(gAccessModifier: "virtual async"));
      #endregion
      #endregion
      MAssemblyGroupCommonConstructorForGHHSAndGHBSPart2(gAssemblyGroupBasicConstructorResult);
      return gAssemblyGroupBasicConstructorResult;
    }
    public static void GAssemblyGroupGHHSFinalizer(IGAssemblyGroupBasicConstructorResult gAssemblyGroupBasicConstructorResult) {
      //#region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor
      //var titularBaseClassName = $"{GAssemblyGroup.GName}Base";
      //var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<IGAssemblyGroup>() {GAssemblyGroup}, gClassName: titularBaseClassName);
      //var GClassBase = titularAssemblyUnitLookupPrimaryConstructorResults.gClasss.First();
      //#endregion
      //#region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
      //var titularClassName = $"{GAssemblyGroup.GName}";
      //var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<IGAssemblyGroup>() {GAssemblyGroup}, gClassName: titularClassName);
      //var GClassDerived = titularAssemblyUnitLookupDerivedClassResults.gClasss.First();
      //#endregion
      //#region Lookup the Interfaces
      //var titularInterfaceDerivedName = $"I{GAssemblyGroup.GName}";
      //var titularAssemblyUnitLookupDerivedInterfacesResults = LookupInterfaces(new List<IGAssemblyGroup>() {GAssemblyGroup}, gInterfaceName: titularInterfaceDerivedName);
      //var gInterfaceDerived = titularAssemblyUnitLookupDerivedInterfacesResults.gInterfaces.First();
      //var titularInterfaceBaseName = $"I{GAssemblyGroup.GName}";
      //var titularAssemblyUnitLookupBaseInterfacesResults = LookupInterfaces(new List<IGAssemblyGroup>() {GAssemblyGroup}, gInterfaceName: titularInterfaceBaseName);
      //var gInterfaceBase = titularAssemblyUnitLookupBaseInterfacesResults.gInterfaces.First();
      //#endregion
     // No Additional work needed, call CommonFinalizer
      GAssemblyGroupCommonFinalizer(gAssemblyGroupBasicConstructorResult);
    }

    //public static void GAssemblyGroupGHHSFinalizer( GAssemblyGroup GAssemblyGroup,  GClass GClassDerived, GClass GClassBase, GInterface gInterfaceDerived, GInterface gInterfaceBase) {
    //  //#region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor
    //  //var titularBaseClassName = $"{GAssemblyGroup.GName}Base";
    //  //var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<IGAssemblyGroup>(){GAssemblyGroup},gClassName:titularBaseClassName) ;
    //  //#endregion
    //  //#region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
    //  //var titularClassName = $"{GAssemblyGroup.GName}";
    //  //var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<IGAssemblyGroup>(){GAssemblyGroup},gClassName:titularClassName) ;
    //  //#endregion
    //  // No Additional work needed, call CommonFinalizer
    //  GAssemblyGroupCommonFinalizer(GAssemblyGroup,  GClassDerived, GClassBase,  gInterfaceDerived,  gInterfaceBase);
    //}

  }
}
