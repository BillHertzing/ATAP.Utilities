using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Collection;
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
    public static (string subDirectoryForGeneratedFiles,
      string baseNamespaceName,
      string gAssemblyGroupName,
      string gTitularAssemblyUnitName,
      string gTitularBaseCompilationUnitName,
      GPatternReplacement gAssemblyGroupPatternReplacement,
      GPatternReplacement gAssemblyUnitPatternReplacement,
      GPatternReplacement gCompilationUnitBasePatternReplacement,
      GAssemblyGroup gAssemblyGroup,
      GAssemblyUnit gTitularAssemblyUnit,
      GCompilationUnit gCompilationUnitBase,
      GCompilationUnit gCompilationUnitDerived,
      GNamespace gNamespaceBase,
      GNamespace gNamespaceDerived,
      GClass gClassBase,
      GClass gClassDerived,
      GMethod gPrimaryConstructorBase,
      GAssemblyUnit gTitularInterfaceAssemblyUnit,
      GCompilationUnit gTitularInterfaceDerivedCompilationUnit,
      GCompilationUnit gTitularInterfaceBaseCompilationUnit,
      GInterface gTitularInterfaceDerivedInterface,
      GInterface gTitularInterfaceBaseInterface
      ) MAssemblyGroupBasicConstructorPart1(string gAssemblyGroupName = default,
        string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
        GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GAssemblyGroup gAssemblyGroup;
      GAssemblyUnit gTitularAssemblyUnit;
      GCompilationUnit gCompilationUnit;
      GUsingGroup gUsingGroup;
      GNamespace gNamespace;
      GPatternReplacement gAssemblyGroupPatternReplacement;
      GPatternReplacement gAssemblyUnitPatternReplacement;

      #region Determine the names Titular and TitularInterfaces Base and Derived CompilationUnits, Namespaces, Classes, and Interfaces
      // everything to the right of the last "." character, returns original string if no "."
      var pos = gAssemblyGroupName.LastIndexOf(".") + 1;
      var gTitularCommonName = gAssemblyGroupName.Substring(pos, gAssemblyGroupName.Length - pos);
      var gTitularAssemblyUnitName = gAssemblyGroupName;
      var gTitularInterfaceAssemblyUnitName = gAssemblyGroupName + ".Interfaces";
      var gNamespaceName = $"{baseNamespaceName}{gTitularCommonName}";
      var gCompilationUnitCommonName = gTitularCommonName;
      var gTitularDerivedCompilationUnitName = gCompilationUnitCommonName;
      var gTitularBaseCompilationUnitName = gCompilationUnitCommonName + "Base";
      var gTitularInterfaceDerivedCompilationUnitName = "I" + gCompilationUnitCommonName;
      var gTitularInterfaceBaseCompilationUnitName = "I" + gCompilationUnitCommonName + "Base";
      var gClassDerivedName = gCompilationUnitCommonName;
      var gClassBaseName = gCompilationUnitCommonName + "Base";
      var gTitularInterfaceDerivedName = "I" + gCompilationUnitCommonName;
      var gTitularInterfaceBaseName = "I" + gCompilationUnitCommonName + "Base";
      #endregion
      #region GReplacementPatternDictionary for AssemblyGroup
      gAssemblyGroupPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyGroupNameReplacementPattern"), gAssemblyGroupName},
        });
      // add the PatternReplacements specified as the gPatternReplacement argument
      foreach (var kvp in gPatternReplacement.GDictionary) {
        gAssemblyGroupPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      #endregion
      #region Instantiate the GAssemblyGroup
      gAssemblyGroup = new GAssemblyGroup(gAssemblyGroupName, gPatternReplacement: gAssemblyGroupPatternReplacement);
      #endregion
      #region Titular AssemblyUnit
      #region GReplacementPatternDictionary for Titular AssemblyUnit
      gAssemblyUnitPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyUnitNameReplacementPattern"), gTitularAssemblyUnitName}
        });
      // add the AssemblyGroup PatternReplacements to the Titular AssemblyUnit PatternReplacements
      gAssemblyUnitPatternReplacement.GDictionary.AddRange(gAssemblyGroupPatternReplacement.GDictionary);
      #endregion
      #region Instantiate the gTitularAssemblyUnit
      gTitularAssemblyUnit = new GAssemblyUnit(gTitularAssemblyUnitName, gRelativePath: gTitularAssemblyUnitName,
        gProjectUnit: new GProjectUnit(gTitularAssemblyUnitName, gPatternReplacement: gAssemblyUnitPatternReplacement),
        gPatternReplacement: gAssemblyUnitPatternReplacement);
      #endregion
      #endregion
      gAssemblyGroup.GAssemblyUnits.Add(gTitularAssemblyUnit.Philote, gTitularAssemblyUnit);
      #region Titular Derived CompilationUnit
      #region Pattern Replacements for Derived CompilationUnit
      var gDerivedCompilationUnitPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), gTitularDerivedCompilationUnitName},
          //{new Regex("DataInitializationReplacementPattern"), tempdatainitialization},
          //{new Regex("DataDisposalReplacementPattern"), ""
          //  // "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();"
          //},
        });
      // add the AssemblyUnit PatternReplacements to the Derived CompilationUnit PatternReplacements
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gDerivedCompilationUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      #endregion
      #region Instantiate the gCompilationUnitDerived
      var gCompilationUnitDerived = new GCompilationUnit(gTitularDerivedCompilationUnitName, gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gDerivedCompilationUnitPatternReplacement);
      #endregion
      gTitularAssemblyUnit.GCompilationUnits.Add(gCompilationUnitDerived.Philote, gCompilationUnitDerived);
      #region Instantiate the gNamespaceDerived
      var gNamespaceDerived = new GNamespace(gNamespaceName);
      #endregion
      gCompilationUnitDerived.GNamespaces.Add(gNamespaceDerived.Philote, gNamespaceDerived);
      #region Instantiate the gClassDerived
      var gClassDerived = new GClass(gClassDerivedName, "public", gAccessModifier: "partial",
        gInheritance: gClassBaseName,
        gImplements: new List<string> {gTitularInterfaceDerivedName} //"IDisposable",
        //gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternDerivedData" }
      );
      #endregion
      gNamespaceDerived.GClasss.Add(gClassDerived.Philote, gClassDerived);
      #endregion

      #region Titular Base CompilationUnit
      #region GReplacementPatternDictionary for CompilationUnit Base CompilationUnit
      var gCompilationUnitBasePatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), gTitularBaseCompilationUnitName},
          //{new Regex("DataInitializationReplacementPattern"), tempdatainitialization}, {
          //  new Regex("DataDisposalReplacementPattern"),
          //  //"SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();"
          //  ""
          //},
        });
      // add the Base AssemblyUnit PatternReplacements to the Base CompilationUnit PatternReplacements
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gCompilationUnitBasePatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      #endregion
      #region Instantiate the gCompilationUnitBase
      var gCompilationUnitBase = new GCompilationUnit(gTitularBaseCompilationUnitName, gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gCompilationUnitBasePatternReplacement);
      #endregion
      gTitularAssemblyUnit.GCompilationUnits.Add(gCompilationUnitBase.Philote, gCompilationUnitBase);
      #region Instantiate the gNamespaceBase
      var gNamespaceBase = new GNamespace(gNamespaceName);
      #endregion
      gCompilationUnitBase.GNamespaces.Add(gNamespaceBase.Philote, gNamespaceBase);
      #region Instantiate the gClassBase
      var gClassBase = new GClass(gClassBaseName, "public", gAccessModifier: "partial",
        //gInheritance: baseClass.GName
        gImplements: new List<string> {gTitularInterfaceBaseName} //, "IDisposable"
        //gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternBaseData" }
      );
      #endregion
      gNamespaceBase.GClasss.Add(gClassBase.Philote, gClassBase);
      #region Instantiate the gPrimaryConstructorBase (Primary Constructor for the Titular Base Class)
      var gPrimaryConstructorBase = new GMethod(new GMethodDeclaration(gClassBaseName, isConstructor: true,
        gVisibility: "public"));
      #endregion
      gClassBase.GMethods.Add(gPrimaryConstructorBase.Philote, gPrimaryConstructorBase);
      #endregion
      //#region Data Initialization (startup?)
      //// ToDo: encapsulate and refactor
      //string tempdatainitialization = @"
      //  /*
      //  #region configurationRoot for this HostedService
      //  // Create the configurationBuilder for this HostedService. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      //  // The Environment has been configured by the GenericHost before this point is reached
      //  // InitialStartupDirectory has been set by the GenericHost before this point is reached, and is where the GenericHost program or service was started
      //  // LoadedFromDirectory has been configured by the GenericHost before this point is reached. It is the location where this assembly resides
      //  // ToDo: Implement these two values into the GenericHost configurationRoot somehow, then remove from the constructor signature
      //  // var loadedFromDirectory = hostConfiguration.GetValue<string>(\SomeStringConstantConfigrootKey\ \./\); //ToDo suport dynamic assembly loading form other Startup directories -  Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      //  // var initialStartupDirectory = hostConfiguration.GetValue<string>(\SomeStringConstantConfigrootKey\ \./\);
      //  // Build the configurationRoot for this service
      //  // var configurationBuilder = ConfigurationExtensions.StandardConfigurationBuilder(loadedFromDirectory, initialStartupDirectory, ConsoleMonitorDefaultConfiguration.Production, ConsoleMonitorStringConstants.SettingsFileName, ConsoleMonitorStringConstants.SettingsFileNameSuffix, StringConstants.CustomEnvironmentVariablePrefix, LoggerFactory, stringLocalizerFactory, hostEnvironment, hostConfiguration, linkedCancellationToken);
      //  // ConfigurationRoot = configurationBuilder.Build();
      //  #endregion
      //  // Embedded object as Data 
      //  //AssemblyUnitNameReplacementPatternBaseData = new AssemblyUnitNameReplacementPatternBaseData();
      //  */";
      //#endregion

      /* ************************************************************************************ */
      #region Titular Interfaces AssemblyUnit
      #region GReplacementPatternDictionary for Titular Interfaces AssemblyUnit
      gAssemblyUnitPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyUnitNameReplacementPattern"), gTitularInterfaceAssemblyUnitName}
        });
      // add the AssemblyGroup PatternReplacements to the Titular Interfaces AssemblyUnit PatternReplacements
      gAssemblyUnitPatternReplacement.GDictionary.AddRange(gAssemblyGroupPatternReplacement.GDictionary);
      #endregion
      #region Instantiate the gTitularInterfaceAssemblyUnit
      var gTitularInterfaceAssemblyUnit = new GAssemblyUnit(gTitularInterfaceAssemblyUnitName,
        gRelativePath: gTitularInterfaceAssemblyUnitName,
        gProjectUnit: new GProjectUnit(gTitularInterfaceAssemblyUnitName,
          gPatternReplacement: gAssemblyUnitPatternReplacement),
        gPatternReplacement: gAssemblyUnitPatternReplacement);
      #endregion
      gAssemblyGroup.GAssemblyUnits.Add(gTitularInterfaceAssemblyUnit.Philote, gTitularInterfaceAssemblyUnit);
      #region Titular Interface Derived CompilationUnit
      #region Pattern Replacements for Interface Derived CompilationUnit
      var gInterfaceDerivedCompilationUnitPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
        });
      gInterfaceDerivedCompilationUnitPatternReplacement.GDictionary.AddRange(gAssemblyUnitPatternReplacement
        .GDictionary);
      #endregion
      #region instantiate the Titular Interface Derived CompilationUnit
      var gTitularInterfaceDerivedCompilationUnit = new GCompilationUnit(gTitularInterfaceDerivedCompilationUnitName,
        gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles,
        gPatternReplacement: gInterfaceDerivedCompilationUnitPatternReplacement);
      #endregion
      gTitularInterfaceAssemblyUnit.GCompilationUnits.Add(gTitularInterfaceDerivedCompilationUnit.Philote,
        gTitularInterfaceDerivedCompilationUnit);
      #region Namespace For Titular Interface Derived CompilationUnit
      var gTitularInterfaceDerivedNamespace = new GNamespace(gNamespaceName);
      #endregion
      gTitularInterfaceDerivedCompilationUnit.GNamespaces.Add(gTitularInterfaceDerivedNamespace.Philote,
        gTitularInterfaceDerivedNamespace);
      #region Create Titular Interface Derived Interface
      var gTitularInterfaceDerivedInterface = new GInterface(gTitularInterfaceDerivedName, "public");
      #endregion
      gTitularInterfaceDerivedNamespace.GInterfaces.Add(gTitularInterfaceDerivedInterface.Philote,
        gTitularInterfaceDerivedInterface);
      #endregion
      #endregion
      #region Titular Interface Base CompilationUnit
      #region Pattern Replacements for Interface Base CompilationUnit
      var gInterfaceBaseCompilationUnitPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
        });
      gInterfaceBaseCompilationUnitPatternReplacement.GDictionary.AddRange(gAssemblyUnitPatternReplacement.GDictionary);
      #endregion
      #region instantiate the Titular Interface Base CompilationUnit
      var gTitularInterfaceBaseCompilationUnit = new GCompilationUnit(gTitularInterfaceBaseCompilationUnitName,
        gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles,
        gPatternReplacement: gInterfaceBaseCompilationUnitPatternReplacement);
      #endregion
      gTitularInterfaceAssemblyUnit.GCompilationUnits.Add(gTitularInterfaceBaseCompilationUnit.Philote,
        gTitularInterfaceBaseCompilationUnit);
      #region Namespace For Titular Interface Base CompilationUnit
      var gTitularInterfaceBaseNamespace = new GNamespace(gNamespaceName);
      #endregion
      gTitularInterfaceBaseCompilationUnit.GNamespaces.Add(gTitularInterfaceBaseNamespace.Philote,
        gTitularInterfaceBaseNamespace);
      #region Create Titular Interface Base Interface
      var gTitularInterfaceBaseInterface = new GInterface(gTitularInterfaceBaseName, "public");
      #endregion
      gTitularInterfaceBaseNamespace.GInterfaces.Add(gTitularInterfaceBaseInterface.Philote,
        gTitularInterfaceBaseInterface);
      #endregion

      /* ************************************************************************************ */
      #region Upate the ProjectUnits for both AssemblyUnits
      #region PropertyGroups common to both AssemblyUnits
      new List<GPropertyGroupInProjectUnit>() {
        PropertyGroupInProjectUnitForProjectUnitIsLibrary(),
        PropertyGroupInProjectUnitForPackableOnBuild(),
        PropertyGroupInProjectUnitForLifecycleStage(),
        PropertyGroupInProjectUnitForBuildConfigurations(),
        PropertyGroupInProjectUnitForVersion()
      }.ForEach(gP => {
        gTitularAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits.Add(gP.Philote, gP);
        gTitularInterfaceAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits.Add(gP.Philote, gP);
      });
      #endregion
      #region ItemGroups common to both AssemblyUnits
      new List<GItemGroupInProjectUnit>() {
        //TBD
      }.ForEach(o => {
        gTitularAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o);
        gTitularInterfaceAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o);
      });
      #endregion
      #region PropertyGroups only in Titular AssemblyUnit
      #endregion
      #region ItemGroups only in Titular AssemblyUnit
      #endregion
      #region Link the Titular Interfaces AssemblyUnit back to the ProjectUnit in the Titular AssemblyUnit
      var gItemGroupInProjectUint = new GItemGroupInProjectUnit(
        gName: "the Titular Interfaces AssemblyUnit",
        gDescription: "The Interfaces for the Classes specified in this assembly",
        gBody: new GBody(gStatements: new List<string>() {
          $"<PackageReference Include=\"{gTitularInterfaceAssemblyUnit.GName}\" />"
        }));
      gTitularAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gItemGroupInProjectUint.Philote,
        gItemGroupInProjectUint);
      #endregion
      #endregion
      var part1Tuple = (subDirectoryForGeneratedFilesValue: subDirectoryForGeneratedFiles,
          baseNamespaceName: baseNamespaceName,
          gAssemblyGroupName: gAssemblyGroupName,
          gTitularAssemblyUnitName: gTitularAssemblyUnitName,
          gTitularBaseCompilationUnitName: gTitularBaseCompilationUnitName,
          gAssemblyGroupPatternReplacement: gAssemblyGroupPatternReplacement,
          gAssemblyUnitPatternReplacement: gAssemblyUnitPatternReplacement,
          gCompilationUnitBasePatternReplacement: gCompilationUnitBasePatternReplacement,
          gAssemblyGroup: gAssemblyGroup,
          gTitularAssemblyUnit: gTitularAssemblyUnit,
          gCompilationUnitBase: gCompilationUnitBase,
          gCompilationUnitDerived: gCompilationUnitDerived,
          gNamespaceBase: gNamespaceBase,
          gNamespaceDerived: gNamespaceDerived,
          gClassBase: gClassBase,
          gClassDerived: gClassDerived,
          gPrimaryConstructorBase: gPrimaryConstructorBase,
          gTitularInterfaceAssemblyUnit: gTitularInterfaceAssemblyUnit,
          gTitularInterfaceDerivedCompilationUnit: gTitularInterfaceDerivedCompilationUnit,
          gTitularInterfaceBaseCompilationUnit: gTitularInterfaceBaseCompilationUnit,
          gTitularInterfaceDerivedInterface: gTitularInterfaceDerivedInterface,
          gTitularInterfaceBaseInterface: gTitularInterfaceBaseInterface
        );
      return part1Tuple;
    }
    public static GAssemblyGroup MAssemblyGroupBasicConstructorPart2(
      (string subDirectoryForGeneratedFiles,
        string baseNamespaceName,
        string gAssemblyGroupName,
        string gAssemblyUnitName,
        string gCompilationUnitName,
        GPatternReplacement gAssemblyGroupPatternReplacement,
        GPatternReplacement gAssemblyUnitPatternReplacement,
        GPatternReplacement gCompilationUnitPatternReplacement,
        GAssemblyGroup gAssemblyGroup,
        GAssemblyUnit gAssemblyUnit,
        GCompilationUnit gCompilationUnit,
        GNamespace gNamespace) part1Tuple,
      GClass gClass
    ) {
      return MAssemblyGroupBasicConstructorPart2(
        part1Tuple.subDirectoryForGeneratedFiles,
        part1Tuple.baseNamespaceName,
        part1Tuple.gAssemblyGroupName,
        part1Tuple.gAssemblyUnitName,
        part1Tuple.gCompilationUnitName,
        part1Tuple.gAssemblyGroupPatternReplacement,
        part1Tuple.gAssemblyUnitPatternReplacement,
        part1Tuple.gCompilationUnitPatternReplacement,
        part1Tuple.gAssemblyGroup,
        part1Tuple.gAssemblyUnit,
        part1Tuple.gCompilationUnit,
        part1Tuple.gNamespace,
        gClass
      );
    }
    public static GAssemblyGroup MAssemblyGroupBasicConstructorPart2(
      string subDirectoryForGeneratedFiles = default,
      string baseNamespaceName = default,
      string gAssemblyGroupName = default,
      string gAssemblyUnitName = default,
      string gCompilationUnitName = default,
      GPatternReplacement gAssemblyGroupPatternReplacement = default,
      GPatternReplacement gAssemblyUnitPatternReplacement = default,
      GPatternReplacement gCompilationUnitPatternReplacement = default,
      GAssemblyGroup gAssemblyGroup = default,
      GAssemblyUnit gAssemblyUnit = default,
      GCompilationUnit gCompilationUnit = default,
      GNamespace gNamespace = default,
      GClass gClass = default
    ) {
      GUsingGroup gUsingGroup;
      GPropertyGroup gPropertyGroup;


      #region StringConstants Base CompilationUnit
      gCompilationUnitPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
        });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gCompilationUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }

      #region Additional StringConstants items
      var gAdditionalStatements = new List<string>() {"{dummyConfigKeyRoot,dummyConfigDefaultString}"};
      #endregion
      gCompilationUnit = CompilationUnitStringConstantsConstructor(gNamespaceName: gNamespace.GName,
        gRelativePath: subDirectoryForGeneratedFiles,
        gPatternReplacement: gCompilationUnitPatternReplacement);
      gAssemblyUnit.GCompilationUnits.Add(gCompilationUnit.Philote, gCompilationUnit);
      #endregion
      return gAssemblyGroup;
    }
    public static void MUpdateGPatternReplacement(GAssemblyGroup gAssemblyGroup,
      GPatternReplacement gAssemblyGroupPatternReplacement) {
    }
  }
}
