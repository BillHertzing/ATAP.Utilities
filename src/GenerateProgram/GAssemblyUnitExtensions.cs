using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using GenerateProgram;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.Lookup;

namespace GenerateProgram {
  public static partial class GAssemblyUnitExtensions {

    public static void GAssemblyGroupCommonFinalizer(GAssemblyGroup gAssemblyGroup) {
      #region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor
      var titularBaseClassName = $"{gAssemblyGroup.GName}Base";
      var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularBaseClassName) ;
      #endregion
      #region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
      var titularClassName = $"{gAssemblyGroup.GName}";
      var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularClassName) ;
      #endregion
      #region Create Derived Constructors for all public Base Constructors
      // Create a constructor in the Titular class for every public constructor in the Titular Base class
      var baseConstructorsList = new List<GMethod>();
      baseConstructorsList.AddRange(titularAssemblyUnitLookupPrimaryConstructorResults.gClasss.First().CombinedConstructors());
      foreach (var bc in baseConstructorsList) {
        var gConstructor = new GMethod(new GMethodDeclaration(titularClassName, isConstructor: true,
          gVisibility: "public", gArguments: bc.GDeclaration.GArguments, gBase: bc.GDeclaration.GArguments.ToBaseString()));
        titularAssemblyUnitLookupDerivedClassResults.gClasss.First().GMethods.Add(gConstructor.Philote,gConstructor);
      }
      #endregion
      #region Constructor Groups
      // ToDo handle method groups, will require a chance to CombinedConstructors
      #endregion
      #region Condense GUsings in Base GCompilationUnit
      #endregion
      #region Condense GItemGroups in Base GAssemblyUnit's GProjectUnit
      #endregion
    }

    //public static IEnumerable<KeyValuePair<Philote<GCompilationUnit>,GCompilationUnit>> AssemblyUnitStringCOnstantsAndLinkedBaseAndDerivedClassConstructor(String gNamespaceName,
    //  string gRelativePathBase = default,
    //  string gRelativePathDerived = default,
    //  string gClassNameCommon = default,
    //  GPatternReplacement gPatternReplacement = default) {

      //GAssemblyUnit gAssemblyUnit;
      //Dictionary<Philote<GCompilationUnit>, GCompilationUnit> gCompilationUnits;
      //GCompilationUnit gCompilationUnit;
      //Dictionary<Philote<GNamespace>, GNamespace> gNamespaces = new Dictionary<Philote<GNamespace>, GNamespace>();
      //GNamespace gNamespace;
      //Dictionary<Philote<GUsing>, GUsing> gUsings;
      //GUsing gUsing;
      //Dictionary<Philote<GClass>, GClass> gClasss;
      //GClass gClass;
      //gClass = new GClass("StringConstants", gVisibility: "public", "static");
      //GConstStringGroup gConstStringGroup = new GConstStringGroup(gName: "Settings File Names");
      //foreach (var kvp in new Dictionary<string, string>() {
      //  {"SettingsFileName","AssemblyUnitNameReplacementPattern"},
      //  {"SettingsFileNameSuffix","json"},
      //}) {
      //  GConstString gConstString = new GConstString(kvp.Key, kvp.Value);
      //  gConstStringGroup.GConstStrings[gConstString.Philote] = gConstString;
      //}
      //gClass.GConstStringGroups[gConstStringGroup.Philote] = gConstStringGroup;
      //gConstStringGroup = new GConstStringGroup(gName: "Temporary File Names");
      //foreach (var kvp in new Dictionary<string, string>() {
      //  {"TemporaryDirectoryBaseConfigRootKey","TemporaryDirectoryBase"},
      //  {"TemporaryDirectoryBaseDefault","D:/Temp/AssemblyUnitNameReplacementPattern/"},
      //}) {
      //  GConstString gConstString = new GConstString(kvp.Key, kvp.Value);
      //  gConstStringGroup.GConstStrings[gConstString.Philote] = gConstString;
      //}
      //gClass.GConstStringGroups[gConstStringGroup.Philote] = gConstStringGroup;
      //gNamespace = new GNamespace(gNamespaceName);
      //gNamespace.GClasss[gClass.Philote] = gClass;
      //gNamespaces = new Dictionary<Philote<GNamespace>, GNamespace> {
      //  { gNamespace.Philote, gNamespace }
      //};
      //gCompilationUnit = new GCompilationUnit("StringConstants", gRelativePath: gRelativePathBase, gNamespaces: gNamespaces, gPatternReplacement: gPatternReplacement);
      //gCompilationUnits = new Dictionary<Philote<GCompilationUnit>,GCompilationUnit>(){{gCompilationUnit.Philote,gCompilationUnit}};
      //#region Base Class Compilation Unit
      //#region Usings
      //// gNamespace.GUsings[gClass.Philote] = gClass;
      //#endregion
      //#region new Namespace
      ////gNamespace = new GNamespace(gNamespaceName);
      //#region Base Class
      //// gClass = new GClass("gName: "${CommonClassName}Base", gVisibility: "public");
      //// gNamespace.GClasss[gClass.Philote] = gClass;
      //#endregion
      //#endregion
      //// gCompilationUnit = new GCompilationUnit(${CommonClassName}Base", gRelativePath: gRelativePathBase, gNamespaces: gNamespaces, gPatternReplacement: gPatternReplacement);
      //#endregion
      //#region Add to Namespaces collection
      ////gNamespaces.Add(gNamespace.Philote, gNamespace);
      //#endregion
      //#region Derived Class Compilation Unit
      //#region Usings
      //// gNamespace.GUsings[gClass.Philote] = gClass;
      //#endregion
      //#region new Namespace
      ////gNamespace = new GNamespace(gNamespaceName);
      //#region Derived Class
      //// gClass = new GClass("gName: "${CommonClassName}", gVisibility: "public");
      //// gNamespace.GClasss[gClass.Philote] = gClass;
      //#endregion
      //#endregion
      //#region new Compilation Unit
      //// gCompilationUnit = new GCompilationUnit(${CommonClassName}", gRelativePath: gRelativePathBase, gNamespaces: gNamespaces, gPatternReplacement: gPatternReplacement);
      //#endregion
      //// Build Derived class
      //// gClass = new GClass("gName: "${CommonClassName}", gVisibility: "public");
      //// gNamespace.GClasss[gClass.Philote] = gClass;
      //gAssemblyUnit = new GAssemblyUnit(gName: "AssemblyUnitNameReplacementPattern", gRelativePath:  gRelativePathBase,gCompilationUnits:gCompilationUnits, gPatternReplacement: gPatternReplacement);

    //  return new KeyValuePair<Philote<GCompilationUnit>, GCompilationUnit>(gAssemblyUnit.Philote, gAssemblyUnit);
    //}

  }
}
