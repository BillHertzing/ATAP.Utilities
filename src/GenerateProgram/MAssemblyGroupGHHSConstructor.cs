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
    public static GAssemblyGroup MAssemblyGroupGHHSConstructor(string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default,
      GPatternReplacement gPatternReplacement = default) {
      var part1Tuple = MAssemblyGroupCommonConstructorForGHHSAndGHBSPart1(gAssemblyGroupName,
        subDirectoryForGeneratedFiles,
        baseNamespace, gPatternReplacement);

      #region Titular Base Class (IHostedService)
      var gClass = new GClass(part1Tuple.gCompilationUnitName, gVisibility: "public",
        gImplements: new List<string> {"IHostedService"}
        //gImplements: new List<string> { "IDisposable" },
        //gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternBaseData" }

      );
      #region specific methods for IHostedService
      gClass.AddMethodGroup(CreateStartStopAsyncMethods(gAccessModifier: "virtual async"));
      #endregion
      #endregion
      var gAssemblyGroup = MAssemblyGroupCommonConstructorForGHHSAndGHBSPart2(part1Tuple, gClass);

      return gAssemblyGroup;
    }
    public static void GAssemblyGroupGHHSFinalizer( GAssemblyGroup gAssemblyGroup) {
      #region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor
      var titularBaseClassName = $"{gAssemblyGroup.GName}Base";
      var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>() {gAssemblyGroup}, gClassName: titularBaseClassName);
      var gClassBase = titularAssemblyUnitLookupPrimaryConstructorResults.gClasss.First();
      #endregion
      #region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
      var titularClassName = $"{gAssemblyGroup.GName}";
      var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<GAssemblyGroup>() {gAssemblyGroup}, gClassName: titularClassName);
      var gClassDerived = titularAssemblyUnitLookupDerivedClassResults.gClasss.First();
      #endregion
      #region Lookup the Interfaces
      var titularInterfaceDerivedName = $"I{gAssemblyGroup.GName}";
      var titularAssemblyUnitLookupDerivedInterfacesResults = LookupInterfaces(new List<GAssemblyGroup>() {gAssemblyGroup}, gInterfaceName: titularInterfaceDerivedName);
      var gInterfaceDerived = titularAssemblyUnitLookupDerivedInterfacesResults.gInterfaces.First();
      var titularInterfaceBaseName = $"I{gAssemblyGroup.GName}";
      var titularAssemblyUnitLookupBaseInterfacesResults = LookupInterfaces(new List<GAssemblyGroup>() {gAssemblyGroup}, gInterfaceName: titularInterfaceBaseName);
      var gInterfaceBase = titularAssemblyUnitLookupBaseInterfacesResults.gInterfaces.First();
      #endregion
     // No Additional work needed, call CommonFinalizer
      GAssemblyGroupCommonFinalizer(gAssemblyGroup,  gClassDerived, gClassBase,  gInterfaceDerived,  gInterfaceBase);
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
