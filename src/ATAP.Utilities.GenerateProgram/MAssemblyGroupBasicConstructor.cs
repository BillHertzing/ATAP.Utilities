using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Collection;
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
        // If HasInterfaces
    public static GAssemblyGroupBasicConstructorResult MAssemblyGroupBasicConstructor(string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true,
      IGPatternReplacement gPatternReplacement = default) {
      var _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;

      #region Determine the names of the Titular Base and Derived CompilationUnits, Namespaces, Classes
      // everything to the right of the last "." character, returns original string if no "."
      var pos = gAssemblyGroupName.LastIndexOf(".") + 1;
      var gTitularCommonName = gAssemblyGroupName.Substring(pos, gAssemblyGroupName.Length - pos);
      var gTitularAssemblyUnitName = gAssemblyGroupName;
      var gNamespaceName = $"{baseNamespaceName}{gTitularCommonName}";
      var gCompilationUnitCommonName = gTitularCommonName;
      var gTitularDerivedCompilationUnitName = gCompilationUnitCommonName;
      var gTitularBaseCompilationUnitName = gCompilationUnitCommonName + "Base";
      var gClassDerivedName = gCompilationUnitCommonName;
      var gClassBaseName = gCompilationUnitCommonName + "Base";
      #endregion
            // If HasInterfaces

      #region Determine the names TitularInterfaces Base and Derived CompilationUnits, Namespaces, Classes
      var gTitularInterfaceAssemblyUnitName = gAssemblyGroupName + ".Interfaces";
      var gTitularInterfaceDerivedCompilationUnitName = "I" + gCompilationUnitCommonName;
      var gTitularInterfaceBaseCompilationUnitName = "I" + gCompilationUnitCommonName + "Base";
      var gTitularInterfaceDerivedName = "I" + gCompilationUnitCommonName;
      var gTitularInterfaceBaseName = "I" + gCompilationUnitCommonName + "Base";
      #endregion
      #region GReplacementPatternDictionary for gAssemblyGroup
      var gAssemblyGroupPatternReplacement = new GPatternReplacement(gName: "gAssemblyGroupPatternReplacement",
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyGroupNameReplacementPattern"), gAssemblyGroupName},
        });
      // add the PatternReplacements specified as the gPatternReplacement argument
      foreach (var kvp in gPatternReplacement.GDictionary) {
        gAssemblyGroupPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      #endregion
      #region Instantiate the GAssemblyGroup
      var gAssemblyGroup =
        new GAssemblyGroup(gName: gAssemblyGroupName, gPatternReplacement: gAssemblyGroupPatternReplacement);
      #endregion
      #region Titular AssemblyUnit
      #region GReplacementPatternDictionary for the Titular AssemblyUnit
      var gTitularAssemblyUnitPatternReplacement = new GPatternReplacement(gName: "gAssemblyUnitPatternReplacement",
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyUnitNameReplacementPattern"), gTitularAssemblyUnitName}
        });
      // add the AssemblyGroup PatternReplacements to the Titular AssemblyUnit PatternReplacements
      gTitularAssemblyUnitPatternReplacement.GDictionary.AddRange(gAssemblyGroupPatternReplacement.GDictionary);
      #endregion
      #region ProjectUnit for the Titular AssemblyUnit
      #region GPatternReplacement for the ProjectUnit
      var gTitularAssemblyUnitProjectUnitPatternReplacement =
        new GPatternReplacement(gName: "TitularAssemblyUnitProjectUnitPatternReplacement");
      gTitularAssemblyUnitProjectUnitPatternReplacement.GDictionary.AddRange(
        gTitularAssemblyUnitPatternReplacement.GDictionary);
      #endregion
      var gTitularAssemblyUnitProjectUnit = new GProjectUnit(gName: gTitularAssemblyUnitName,
        gPatternReplacement: gTitularAssemblyUnitProjectUnitPatternReplacement);
      #endregion
      #region Instantiate the gTitularAssemblyUnit
      var gTitularAssemblyUnit = new GAssemblyUnit(gName: gTitularAssemblyUnitName,
        gRelativePath: gTitularAssemblyUnitName,
        gProjectUnit: gTitularAssemblyUnitProjectUnit,
        gPatternReplacement: gTitularAssemblyUnitPatternReplacement);
      #endregion
      #endregion
      gAssemblyGroup.GAssemblyUnits.Add(gTitularAssemblyUnit.Philote, gTitularAssemblyUnit);
      #region Titular Derived CompilationUnit
      #region Pattern Replacements for Titular Derived CompilationUnit
      var gTitularDerivedCompilationUnitPatternReplacement = new GPatternReplacement(gName:"gTitularDerivedCompilationUnitPatternReplacement",
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), gTitularDerivedCompilationUnitName},
          //{new Regex("DataInitializationReplacementPattern"), tempdatainitialization},
          //{new Regex("DataDisposalReplacementPattern"), ""
          //  // "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();"
          //},
        });
      // add the AssemblyUnit PatternReplacements to the Derived CompilationUnit PatternReplacements
      gTitularDerivedCompilationUnitPatternReplacement.GDictionary.AddRange(gTitularAssemblyUnitPatternReplacement
        .GDictionary);
      #endregion
      #region Instantiate the Titular Derived CompilationUnit
      var gTitularDerivedCompilationUnit = new GCompilationUnit(gTitularDerivedCompilationUnitName, gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gTitularDerivedCompilationUnitPatternReplacement);
      #endregion
      gTitularAssemblyUnit.GCompilationUnits.Add(gTitularDerivedCompilationUnit.Philote, gTitularDerivedCompilationUnit);
      #region Instantiate the gNamespaceDerived
      var gNamespaceDerived = new GNamespace(gNamespaceName);
      #endregion
      gTitularDerivedCompilationUnit.GNamespaces.Add(gNamespaceDerived.Philote, gNamespaceDerived);
      #region Instantiate the gClassDerived
      // If hasInterfaces, the derived class Implements the Interface
      GClass gClassDerived;
      if (hasInterfaces) {
      gClassDerived = new GClass(gClassDerivedName, "public", gAccessModifier: "partial",
        gInheritance: gClassBaseName,
        gImplements: new List<string> {gTitularInterfaceDerivedName} 
        //gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternDerivedData" }
      );
      } else {
        gClassDerived = new GClass(gClassDerivedName, "public", gAccessModifier: "partial",
        gInheritance: gClassBaseName
        //Implements: new List<string> {gTitularInterfaceDerivedName}  -- No Interfaces in this AssemblyGroup
        //gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternDerivedData" }
      );        
      }

      #endregion
      gNamespaceDerived.GClasss.Add(gClassDerived.Philote, gClassDerived);
      #endregion

      #region Titular Base CompilationUnit
      #region Pattern Replacements for Derived CompilationUnit
      var gTitularBaseCompilationUnitPatternReplacement = new GPatternReplacement(gName:"gTitularBaseCompilationUnitPatternReplacement",
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), gTitularBaseCompilationUnitName},
          //{new Regex("DataInitializationReplacementPattern"), tempdatainitialization}, {
          //  new Regex("DataDisposalReplacementPattern"),
          //  //"SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();"
          //  ""
          //},
        });
      // add the AssemblyUnit PatternReplacements to the Base CompilationUnit PatternReplacements
      foreach (var kvp in gTitularAssemblyUnitPatternReplacement.GDictionary) {
        gTitularBaseCompilationUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      #endregion
      #region Instantiate the Titular Base CompilationUnit
      var gTitularBaseCompilationUnit = new GCompilationUnit(gTitularBaseCompilationUnitName, gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gTitularBaseCompilationUnitPatternReplacement);
      #endregion
      gTitularAssemblyUnit.GCompilationUnits.Add(gTitularBaseCompilationUnit.Philote, gTitularBaseCompilationUnit);
      #region Instantiate the gNamespaceBase
      var gNamespaceBase = new GNamespace(gNamespaceName);
      #endregion
      gTitularBaseCompilationUnit.GNamespaces.Add(gNamespaceBase.Philote, gNamespaceBase);
      #region Instantiate the gClassBase
      var gClassBase = new GClass(gClassBaseName, "public", gAccessModifier: "partial",
        //gInheritance: baseClass.GName
              // If HasInterfaces

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
            // If HasInterfaces

      #region Titular Interfaces AssemblyUnit
      #region GReplacementPatternDictionary for Titular Interfaces AssemblyUnit
      var gTitularInterfaceAssemblyUnitPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyUnitNameReplacementPattern"), gTitularInterfaceAssemblyUnitName}
        });
      // add the AssemblyGroup PatternReplacements to the Titular Interface AssemblyUnit PatternReplacements
      gTitularInterfaceAssemblyUnitPatternReplacement.GDictionary.AddRange(gAssemblyGroupPatternReplacement.GDictionary);
      #endregion
      #region ProjectUnit for the Titular Interface AssemblyUnit
      #region GPatternReplacement for the ProjectUnit
      var gTitularInterfaceAssemblyUnitProjectUnitPatternReplacement =
        new GPatternReplacement(gName: "TitularInterfaceAssemblyUnitProjectUnitPatternReplacement");
      gTitularInterfaceAssemblyUnitProjectUnitPatternReplacement.GDictionary.AddRange(
        gTitularInterfaceAssemblyUnitPatternReplacement.GDictionary);
      #endregion
      var gTitularInterfaceAssemblyUnitProjectUnit = new GProjectUnit(gTitularInterfaceAssemblyUnitName,
        gPatternReplacement: gTitularInterfaceAssemblyUnitProjectUnitPatternReplacement);
      #endregion
      #region Instantiate the gTitularInterfaceAssemblyUnit
      var gTitularInterfaceAssemblyUnit = new GAssemblyUnit(gName: gTitularInterfaceAssemblyUnitName,
        gRelativePath: gTitularInterfaceAssemblyUnitName,
        gProjectUnit: gTitularInterfaceAssemblyUnitProjectUnit,
        gPatternReplacement: gTitularInterfaceAssemblyUnitPatternReplacement);
      #endregion
      gAssemblyGroup.GAssemblyUnits.Add(gTitularInterfaceAssemblyUnit.Philote, gTitularInterfaceAssemblyUnit);
      #region Titular Interface Derived CompilationUnit
      #region Pattern Replacements for Titular Interface Derived CompilationUnit
      var gInterfaceDerivedCompilationUnitPatternReplacement = new GPatternReplacement(gName:"gTitularInterfaceDerivedCompilationUnitPatternReplacement",
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), gTitularInterfaceDerivedCompilationUnitName}
        });
      // add the interface AssemblyUnit PatternReplacements to the Interface Derived CompilationUnit PatternReplacements
      gInterfaceDerivedCompilationUnitPatternReplacement.GDictionary.AddRange(gTitularInterfaceAssemblyUnitPatternReplacement
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
      gInterfaceBaseCompilationUnitPatternReplacement.GDictionary.AddRange(gTitularInterfaceAssemblyUnitPatternReplacement.GDictionary);
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
      #region Update the ProjectUnits for both AssemblyUnits
      #region PropertyGroups common to both AssemblyUnits
      new List<GPropertyGroupInProjectUnit>() {
        PropertyGroupInProjectUnitForProjectUnitIsLibrary(),
        PropertyGroupInProjectUnitForPackableOnBuild(),
        PropertyGroupInProjectUnitForLifecycleStage(),
        PropertyGroupInProjectUnitForBuildConfigurations(),
        PropertyGroupInProjectUnitForVersionInfo()
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
      GAssemblyGroupBasicConstructorResult mCreateAssemblyGroupResult = new GAssemblyGroupBasicConstructorResult() {
        subDirectoryForGeneratedFiles = subDirectoryForGeneratedFiles,
        baseNamespaceName = baseNamespaceName,
        gAssemblyGroupName = gAssemblyGroupName,
        gTitularAssemblyUnitName = gTitularAssemblyUnitName,
        gTitularBaseCompilationUnitName = gTitularBaseCompilationUnitName,
        gAssemblyGroup = gAssemblyGroup,
        gAssemblyGroupPatternReplacement = gAssemblyGroupPatternReplacement,
        gTitularAssemblyUnit = gTitularAssemblyUnit,
        gTitularAssemblyUnitPatternReplacement = gTitularAssemblyUnitPatternReplacement,
        gTitularDerivedCompilationUnit = gTitularDerivedCompilationUnit,
        gTitularDerivedCompilationUnitPatternReplacement = gTitularDerivedCompilationUnitPatternReplacement,
        gTitularBaseCompilationUnit = gTitularBaseCompilationUnit,
        gTitularBaseCompilationUnitPatternReplacement = gTitularBaseCompilationUnitPatternReplacement,
        gNamespaceDerived = gNamespaceDerived,
        gNamespaceBase = gNamespaceBase,
        gClassBase = gClassBase,
        gClassDerived = gClassDerived,
        gPrimaryConstructorBase = gPrimaryConstructorBase,
              // If HasInterfaces

        gTitularInterfaceAssemblyUnit = gTitularInterfaceAssemblyUnit,
        gTitularInterfaceDerivedCompilationUnit = gTitularInterfaceDerivedCompilationUnit,
        gTitularInterfaceBaseCompilationUnit = gTitularInterfaceBaseCompilationUnit,
        gTitularInterfaceDerivedInterface = gTitularInterfaceDerivedInterface,
        gTitularInterfaceBaseInterface = gTitularInterfaceBaseInterface
      };
      return mCreateAssemblyGroupResult;
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
      return MAssemblyGroupStringConstants(
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
    public static GAssemblyGroup MAssemblyGroupStringConstants(GAssemblyGroupBasicConstructorResult gAssemblyGroupBasicConstructorResult) {
      return MAssemblyGroupStringConstants(
        gAssemblyGroupBasicConstructorResult.subDirectoryForGeneratedFiles,
        gAssemblyGroupBasicConstructorResult.baseNamespaceName,
        gAssemblyGroupBasicConstructorResult.gAssemblyGroupName,
        gAssemblyGroupBasicConstructorResult.gAssemblyGroupName,
        gAssemblyGroupBasicConstructorResult.gTitularBaseCompilationUnitName,
        gAssemblyGroupBasicConstructorResult.gAssemblyGroupPatternReplacement,
        gAssemblyGroupBasicConstructorResult.gTitularAssemblyUnitPatternReplacement,
        gAssemblyGroupBasicConstructorResult.gTitularDerivedCompilationUnitPatternReplacement,
        gAssemblyGroupBasicConstructorResult.gAssemblyGroup,
        gAssemblyGroupBasicConstructorResult.gTitularAssemblyUnit,
        gAssemblyGroupBasicConstructorResult.gTitularBaseCompilationUnit,
        gAssemblyGroupBasicConstructorResult.gNamespaceBase
        //gClass
      );
    }
    public static GAssemblyGroup MAssemblyGroupStringConstants(
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
      //GUsingGroup gUsingGroup; These seem to be unnecessary, deprecating
      //GPropertyGroup gPropertyGroup;
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
      gAssemblyGroup.GPatternReplacement.GDictionary.AddRange(gAssemblyGroupPatternReplacement.GDictionary);
      foreach (var gAssemblyUnitKVP in gAssemblyGroup.GAssemblyUnits) {
        gAssemblyUnitKVP.Value.GPatternReplacement.GDictionary.AddRange(gAssemblyGroupPatternReplacement.GDictionary);
        gAssemblyUnitKVP.Value.GProjectUnit.GPatternReplacement.GDictionary.AddRange(gAssemblyGroupPatternReplacement
          .GDictionary);
        foreach (var gCompilationUnitKVP in gAssemblyUnitKVP.Value.GCompilationUnits) {
          gCompilationUnitKVP.Value.GPatternReplacement.GDictionary.AddRange(gAssemblyGroupPatternReplacement
            .GDictionary);
        }
        foreach (var gResourceUnitKVP in gAssemblyUnitKVP.Value.GResourceUnits) {
          gResourceUnitKVP.Value.GPatternReplacement.GDictionary.AddRange(gAssemblyGroupPatternReplacement.GDictionary);
        }
        //foreach (var gPropertiesUnitKVP in gAssemblyUnitKVP.Value.GPropertiesUnits) {
        //  gPropertiesUnitKVP.Value.GPatternReplacement.GDictionary.AddRange(gAssemblyGroupPatternReplacement.GDictionary);
        //}
      }
    }
  }
}
