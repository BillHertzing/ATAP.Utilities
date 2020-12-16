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
    public static GAssemblyGroupBasicConstructorResult MAssemblyGroupCommonConstructorForGHHSAndGHBS(string gAssemblyGroupName = default,
        string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true,
        GPatternReplacement gPatternReplacement = default) {
      var gAssemblyGroupBasicConstructorResult = MAssemblyGroupBasicConstructor(gAssemblyGroupName,
        subDirectoryForGeneratedFiles, baseNamespaceName, hasInterfaces, gPatternReplacement);
      //var gTitularAssemblyUnitName = gAssemblyGroupName;
      //GPatternReplacement _gPatternReplacement =
      //  gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;

      //GAssemblyGroup gAssemblyGroup;
      //GAssemblyUnit gAssemblyUnit;
      //GCompilationUnit gCompilationUnit;
      //GUsingGroup gUsingGroup;
      //GNamespace gNamespace;
      //GPatternReplacement gAssemblyGroupPatternReplacement;
      //GPatternReplacement gAssemblyUnitPatternReplacement;

      //#region GReplacementPatternDictionary for AssemblyGroup
      //gAssemblyGroupPatternReplacement = new GPatternReplacement(
      //  gDictionary: new Dictionary<Regex, string>() {
      //    {new Regex("AssemblyGroupNameReplacementPattern"), gAssemblyGroupName}, {
      //      new Regex("SolutionReferencedProjectsBasePathReplacementPattern"),
      //      @"C:/Dropbox/whertzing/GitHub/ATAP.Utilities/"
      //    }, {
      //      new Regex("SolutionReferencedProjectsLocalBasePathReplacementPattern"), @"D:/Temp/GenerateProgramArtifacts/"
      //    },
      //  });
      //// add the argument transform
      //foreach (var kvp in gPatternReplacement.GDictionary) {
      //  gAssemblyGroupPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      //}
      //#endregion
      //gAssemblyGroup = new GAssemblyGroup(gAssemblyGroupName, gPatternReplacement: gAssemblyGroupPatternReplacement);

      //#region Titular AssemblyUnit
      //var gAssemblyUnitName = $"{gAssemblyGroupName}";
      //#region GReplacementPatternDictionary for AssemblyUnit
      //gAssemblyUnitPatternReplacement = new GPatternReplacement(
      //  gDictionary: new Dictionary<Regex, string>() {
      //    {new Regex("AssemblyUnitNameReplacementPattern"), gAssemblyUnitName}
      //  });
      //foreach (var kvp in gAssemblyGroupPatternReplacement.GDictionary) {
      //  gAssemblyUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      //}
      //#endregion
      //gAssemblyUnit = new GAssemblyUnit(gAssemblyUnitName, gRelativePath: gAssemblyUnitName,
      //  gProjectUnit: new GProjectUnit(gAssemblyUnitName, gPatternReplacement: gAssemblyUnitPatternReplacement),
      //  gPatternReplacement: gAssemblyUnitPatternReplacement);
      //#endregion
      //#region Titular Base CompilationUnit
      //var gCompilationUnitName = $"{gAssemblyUnitName}Base";
      //#region GReplacementPatternDictionary for CompilationUnit Base CompilationUnit
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
      //var gCompilationUnitPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
      //  {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"},
      //  {new Regex("DataInitializationInStartAsyncReplacementPattern"), tempdatainitialization}, {
      //    new Regex("DataDisposalInStopAsyncReplacementPattern"),
      //    //"SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();"
      //    ""
      //  },
      //});
      //foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
      //  gCompilationUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      //}
      //#endregion
      //gCompilationUnit = new GCompilationUnit(gCompilationUnitName, gFileSuffix: ".cs",
      //  gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gCompilationUnitPatternReplacement);
      #region Add UsingGroups common to both the Titular Derived CompilationUnit and the Titular Base CompilationUnit
      var gUsingGroup = MUsingGroupForMicrosoftGenericHostInGHHSAndGHBS();
      gAssemblyGroupBasicConstructorResult.gTitularDerivedCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      gAssemblyGroupBasicConstructorResult.gTitularBaseCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      gUsingGroup = MUsingGroupForSystemGenericHostInGHHSAndGHBS();
      gAssemblyGroupBasicConstructorResult.gTitularDerivedCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      gAssemblyGroupBasicConstructorResult.gTitularBaseCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Add UsingGroups specific to the Titular Base CompilationUnit
      #endregion
      #region Standard Property Group for every GenericHostHostedService
      var gPropertyGroup = new GPropertyGroup("Standard Properties for every GenericHostHostedService");
      gAssemblyGroupBasicConstructorResult.gClassBase.AddPropertyGroups(gPropertyGroup);
      foreach (var o in new List<GProperty>() {
        new GProperty("ConfigurationRoot", gType: "ConfigurationRoot", gAccessors: "{ get; }",
          gVisibility: "protected internal"),
      }) {
        gPropertyGroup.GPropertys.Add(o.Philote, o);
      }
      #endregion
      #region Injected AutoProperty Group and their derived AutoProperty Groups for every GenericHostHostedService
      #region Injected AutoProperties whose Type IS their name
      gPropertyGroup = new GPropertyGroup("Injected AutoProperty Group for GenericHost");
      gAssemblyGroupBasicConstructorResult.gClassBase.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in new List<string>() {
        "LoggerFactory",
        "StringLocalizerFactory",
        "HostEnvironment",
        "HostLifetime",
        "HostApplicationLifetime"
      }) {
        gAssemblyGroupBasicConstructorResult.gClassBase.AddTConstructorAutoPropertyGroup(
          gAssemblyGroupBasicConstructorResult.gPrimaryConstructorBase.Philote, ap, gPropertyGroupId: gPropertyGroup.Philote);
      }
      #endregion
      #region Injected AutoProperties whose Type is NOT their name
      foreach (var ap in new List<string>() {"HostConfiguration", "AppConfiguration"}) {
        gAssemblyGroupBasicConstructorResult.gClassBase.AddTConstructorAutoPropertyGroup(
          gAssemblyGroupBasicConstructorResult.gPrimaryConstructorBase.Philote, ap, gType: "IConfiguration",
          gPropertyGroupId: gPropertyGroup.Philote);
      }
      #endregion
      #region Derived AutoProperty Group for Logger
      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Logger");
      gAssemblyGroupBasicConstructorResult.gClassBase.AddPropertyGroups(gPropertyGroup);
      gAssemblyGroupBasicConstructorResult.gClassBase.AddTLoggerConstructorAutoPropertyGroup(
        gAssemblyGroupBasicConstructorResult.gPrimaryConstructorBase.Philote, gPropertyGroupId: gPropertyGroup.Philote);
      #endregion
      #region Derived AutoProperty Group for Localizers
      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Localizers");
      gAssemblyGroupBasicConstructorResult.gClassBase.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in new List<string>() {"DebugLocalizer", "ExceptionLocalizer", "UiLocalizer"}) {
        gAssemblyGroupBasicConstructorResult.gClassBase.AddTLocalizerConstructorAutoPropertyGroup(
          gAssemblyGroupBasicConstructorResult.gPrimaryConstructorBase.Philote, ap, gAssemblyGroupBasicConstructorResult.gTitularAssemblyUnitName,
          gPropertyGroupId: gPropertyGroup.Philote);
      }
      #endregion
      #endregion

      #region standard Methods for every GenericHostHostedService
      gAssemblyGroupBasicConstructorResult.gClassBase.AddMethodGroup(MCreateHostApplicationLifetimeEventHandlerMethods());
      #endregion
      return gAssemblyGroupBasicConstructorResult;
      
    }
    //#region Titular Base Class (IHostedService)
    //  GClass gClass = new GClass(gCompilationUnitName, gVisibility: "public",
    //    gInheritance: "BackgroundService",
    //    gImplements: new List<string> { "IDisposable" },
    //    gDisposesOf: new List<string> { "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle" });
    //  #region specific methods for BackgroundService
    //  gClass.AddMethod(MCreateExecuteAsyncMethod(gAccessModifier: "override async"));
    //  gClass.AddMethodGroup(MCreateStartStopAsyncMethods(gAccessModifier: "override async"));
    //  #endregion
    //  #region Constructors
    //  gConstructor = new GMethod(new GMethodDeclaration(gCompilationUnitName, isConstructor: true,
    //    gVisibility: "public"));
    //  gClass.GMethods.Add(gConstructor.Philote,gConstructor);
    //  #endregion
    public static void MAssemblyGroupCommonConstructorForGHHSAndGHBSPart2(
      GAssemblyGroupBasicConstructorResult mCreateAssemblyGroupResult)
     {
      #region Add a StateMachine for the service
      #region Declare and populate the initial initialDiGraphList, which handles basic states for a GHS
      List<string> initialDiGraphList = new List<string>() {
        @"WaitingForInitialization ->ServiceFaulted [label = ""AnyException""]",
        @"WaitingForInitialization ->ShutdownStarted [label = ""StopAsyncActivated""]",
        @"ServiceFaulted ->ShutdownStarted [label = ""CancellationTokenActivated""]",
        @"ServiceFaulted ->ShutdownStarted [label = ""StopAsyncActivated""]",
        @"ShutdownStarted->ShutDownComplete [label = ""AllShutDownStepsCompleted""]",
      };
      #endregion
      MStateMachineConstructor(mCreateAssemblyGroupResult.gTitularBaseCompilationUnit,mCreateAssemblyGroupResult.gNamespaceBase ,  mCreateAssemblyGroupResult.gClassBase, mCreateAssemblyGroupResult.gPrimaryConstructorBase, initialDiGraphList);
      #endregion


      #region ResourceUnits
      GResourceUnit gResourceUnit;
      GResourceItem gResourceItem;
      Dictionary<Philote<GResourceItem>, GResourceItem> gResourceItems;

      GPatternReplacement gExceptionMessagesResourcePatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("ExceptionMessagesResourceUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
        });
      gExceptionMessagesResourcePatternReplacement.GDictionary.AddRange(mCreateAssemblyGroupResult.gTitularAssemblyUnitPatternReplacement.GDictionary);
      gResourceItem = new GResourceItem(gName: "ExceptionMessage1", gValue: "text for exception {0}",
        gComment: "{0} is the exception something?");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem> {[gResourceItem.Philote] = gResourceItem};
      gResourceUnit =
        new GResourceUnit("ExceptionMessages", gRelativePath: "Resources", gResourceItems: gResourceItems,
          gPatternReplacement: gExceptionMessagesResourcePatternReplacement);
      mCreateAssemblyGroupResult.gTitularAssemblyUnit.GResourceUnits.Add(gResourceUnit.Philote, gResourceUnit);
      mCreateAssemblyGroupResult.gTitularAssemblyUnit.GProjectUnit.GResourceUnits.Add(gResourceUnit.Philote, gResourceUnit);
      GPatternReplacement gUIMessagesResourcePatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("ExceptionMessagesResourceUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
        });
      gUIMessagesResourcePatternReplacement.GDictionary.AddRange(mCreateAssemblyGroupResult.gTitularAssemblyUnitPatternReplacement.GDictionary);
      gResourceItem = new GResourceItem(gName: "Enter Selection>", gValue: "Enter Selection>",
        gComment: "Enter Selection prompt for Console UI");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem> {[gResourceItem.Philote] = gResourceItem};
      gResourceUnit = new GResourceUnit("UIMessages", gRelativePath: "Resources", gResourceItems: gResourceItems,
        gPatternReplacement: gUIMessagesResourcePatternReplacement);
      mCreateAssemblyGroupResult.gTitularAssemblyUnit.GResourceUnits.Add(gResourceUnit.Philote, gResourceUnit);
      mCreateAssemblyGroupResult.gTitularAssemblyUnit.GProjectUnit.GResourceUnits.Add(gResourceUnit.Philote, gResourceUnit);
      #endregion

      //#region StringConstants Base CompilationUnit
      //mCreateAssemblyGroupResult.gTitularBaseCompilationUnitPatternReplacement = new GPatternReplacement(
      //  gDictionary: new Dictionary<Regex, string>() {
      //    {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
      //  });
      //foreach (var kvp in mCreateAssemblyGroupResult.gAssemblyUnitPatternReplacement.GDictionary) {
      //  mCreateAssemblyGroupResult.gTitularBaseCompilationUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      //}

      #region DefaultConfiguration CompilationUnit
      #region GPatternReplacement for the DefaultConfiguration CompilationUnit
      var gTitularAssemblyUnitDefaultConfigurationPatternReplacement =
        new GPatternReplacement(gName: "gTitularAssemblyUnitDefaultConfigurationPatternReplacement");
      gTitularAssemblyUnitDefaultConfigurationPatternReplacement.GDictionary.AddRange(
        mCreateAssemblyGroupResult.gTitularAssemblyUnitPatternReplacement.GDictionary);
      #endregion
      #region Additional DefaultConfiguration items
      var gAdditionalStatements = new List<string>() {"{dummyConfigKeyRoot,dummyConfigDefaultString}"};
      #endregion
      var gCompilationUnit = CompilationUnitDefaultConfigurationConstructor(gNamespaceName: mCreateAssemblyGroupResult.gNamespaceDerived.GName ,
        gRelativePath: mCreateAssemblyGroupResult.subDirectoryForGeneratedFiles , gAdditionalStatements: gAdditionalStatements,
        gPatternReplacement: gTitularAssemblyUnitDefaultConfigurationPatternReplacement );
      mCreateAssemblyGroupResult.gTitularAssemblyUnit.GCompilationUnits.Add(gCompilationUnit.Philote, gCompilationUnit);
      #endregion
      #region Settings File(s) for Configuration
      #endregion
      #region Upate the ProjectUnit in the Titular AssemblyUnit
     
      #region ItemGroups for the ProjectUnit
      var gItemGroupInProjectUnitList = MGenericHostServiceCommonItemGroupInProjectUnitList();

      gItemGroupInProjectUnitList.ForEach(o =>
        mCreateAssemblyGroupResult.gTitularAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o));
      //_projectReferences.ForEach(o =>
      //  gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o));
      //_packageReferences.ForEach(o =>
      //  gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o));
      #endregion
      #endregion
      // gAssemblyGroup.GAssemblyUnits.Add(gAssemblyUnit.Philote, gAssemblyUnit);
      /* ************************************************************************************ */
      //#region Interfaces
      //#region Pattern Replacements for AssemblyUnit
      //gAssemblyUnitPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
      //  {new Regex("AssemblyUnitNameReplacementPattern"), $"{gAssemblyGroupName}"}
      //});
      //foreach (var kvp in gAssemblyGroupPatternReplacement.GDictionary) {
      //  gAssemblyUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      //}
      //#endregion
      //#region Create AssemblyUnit for Interfaces
      //gAssemblyUnitName = $"{gAssemblyGroupName}.Interfaces";
      //gAssemblyUnit = new GAssemblyUnit($"{gAssemblyUnitName}",
      //  gRelativePath: $"{gAssemblyUnitName}",
      //  gProjectUnit: new GProjectUnit($"{gAssemblyUnitName}",
      //    gPatternReplacement: gAssemblyUnitPatternReplacement), gPatternReplacement: gAssemblyUnitPatternReplacement);
      //#endregion
      //#region Pattern Replacements for CompilationUnit
      //gCompilationUnitPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
      //  {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
      //});
      //foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
      //  gCompilationUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      //}
      //#endregion
      //#region Create CompilationUnit for Titular Base Interface CompilationUnit
      //var compilationUnitName = $"I{baseCompilationUnitName}";
      //gCompilationUnit = new GCompilationUnit($"{compilationUnitName}", gFileSuffix: ".cs",
      //  gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gCompilationUnitPatternReplacement);
      //gAssemblyUnit.GCompilationUnits.Add(gCompilationUnit.Philote, gCompilationUnit);
      #region Usings For Titular Base Interface CompilationUnit
      var gUsingGroup = MUsingGroupForMicrosoftGenericHostInGHHSAndGHBS();
      mCreateAssemblyGroupResult.gTitularInterfaceBaseCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      gUsingGroup = MUsingGroupForSystemGenericHostInGHHSAndGHBS();
      mCreateAssemblyGroupResult.gTitularInterfaceBaseCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      //#region Namespace For Titular Base Interface CompilationUnit
      //gNamespace = new GNamespace($"{baseNamespaceName}.{gAssemblyGroupName}");
      //gCompilationUnit.GNamespaces.Add(gNamespace.Philote, gNamespace);
      //#endregion
      //#region Create Interface for Titular Base Interface CompilationUnit (IHostedService)
      //var baseInterfaceName = $"I{baseCompilationUnitName}";
      //var gInterface = new GInterface(baseInterfaceName, "public");
      //gNamespace.GInterfaces.Add(gInterface.Philote, gInterface);
      //#endregion
      //#endregion
      #region Create CompilationUnit for Titular Interface CompilationUnit
      //compilationUnitName = $"I{gAssemblyGroupName}";
      //gCompilationUnit = new GCompilationUnit($"{compilationUnitName}", gFileSuffix: ".cs",
      //  gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gCompilationUnitPatternReplacement);
      //gAssemblyUnit.GCompilationUnits.Add(gCompilationUnit.Philote, gCompilationUnit);
      #region Usings For Titular Interface CompilationUnit
      gUsingGroup = MUsingGroupForSystemGenericHostInGHHSAndGHBS();
      mCreateAssemblyGroupResult.gTitularInterfaceDerivedCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      //#region Namespace For Titular Interface CompilationUnit
      //gNamespace = new GNamespace($"{baseNamespaceName}.{gAssemblyGroupName}");
      //gCompilationUnit.GNamespaces.Add(gNamespace.Philote, gNamespace);
      //#endregion
      //#region Create Interface for Titular Interface CompilationUnit (IHostedService)
      //var titularInterfaceName = $"I{gAssemblyGroupName}";
      //gInterface = new GInterface(titularInterfaceName, "public",
      //  gImplements: new List<string>() {$"{baseInterfaceName}"});
      //gNamespace.GInterfaces.Add(gInterface.Philote, gInterface);
      //#endregion
      #endregion
      #region Upate the ProjectUnit in the Interfaces AssemblyUnit
      //#region PropertyGroups for the ProjectUnit in the Interfaces AssemblyUnit
      //var gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForProjectUnitIsLibrary();
      //gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
      //  gPropertyGroupInProjectUnit;
      //gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForPackableOnBuild();
      //gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
      //  gPropertyGroupInProjectUnit;
      //gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForLifecycleStage();
      //gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
      //  gPropertyGroupInProjectUnit;
      //gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForBuildConfigurations();
      //gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
      //  gPropertyGroupInProjectUnit;
      //gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForVersion();
      //gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
      //  gPropertyGroupInProjectUnit;
      //#endregion
      #region ItemGroups for the ProjectUnit in the Interfaces AssemblyUnit
       new List<GItemGroupInProjectUnit>() {
        NetCoreGenericHostReferencesItemGroupInProjectUnit(),
      }.ForEach(o => mCreateAssemblyGroupResult.gTitularInterfaceAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o));
      #endregion
      #endregion
      //gAssemblyGroup.GAssemblyUnits.Add(gAssemblyUnit.Philote, gAssemblyUnit);
      //#endregion
      //return gAssemblyGroup;
    }
    //public static void GAssemblyGroupGHBSFinalizer(GAssemblyGroup gAssemblyGroup,  GClass gClassDerived, GClass gClassBase, GInterface gInterfaceDerived, GInterface gInterfaceBase) {
    //  //#region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor
    //  //var titularBaseClassName = $"{gAssemblyGroup.GName}Base";
    //  //var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularBaseClassName) ;
    //  //#endregion
    //  //#region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
    //  //var titularClassName = $"{gAssemblyGroup.GName}";
    //  //var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularClassName) ;
    //  //#endregion
    //  // No Additional work needed, call CommonFinalizer
    //  GAssemblyGroupCommonFinalizer(gAssemblyGroup,  gClassDerived,  gClassBase,  gInterfaceDerived,  gInterfaceBase);
    //}
  }
}
