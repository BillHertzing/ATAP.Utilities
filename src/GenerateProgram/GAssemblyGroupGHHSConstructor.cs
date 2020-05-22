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
    public static GAssemblyGroup GAssemblyGroupGHHSConstructor(string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GAssemblyGroup gAssemblyGroup;
      GAssemblyUnit gAssemblyUnit;
      GResourceUnit gResourceUnit;
      GResourceItem gResourceItem;
      Dictionary<Philote<GResourceItem>, GResourceItem> gResourceItems;
      GCompilationUnit gCompilationUnit;
      GUsing gUsing;
      GUsingGroup gUsingGroup;
      GNamespace gNamespace;
      GClass gClass;
      GPropertyGroup gPropertyGroup;
      GMethod gConstructor;
      List<string> gAdditionalStatements;
      GInterface gInterface;
      GPropertyGroupInProjectUnit gPropertyGroupInProjectUnit;
      GPatternReplacement gAssemblyGroupPatternReplacement;
      GPatternReplacement gAssemblyUnitPatternReplacement;
      GPatternReplacement gCompilationPatternReplacement;

      #region GReplacementPatternDictionary for AssemblyGroup
      gAssemblyGroupPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyGroupNameReplacementPattern"), gAssemblyGroupName}, {
            new Regex("SolutionReferencedProjectsBasePathReplacementPattern"),
            @"C:/Dropbox/whertzing/GitHub/ATAP.Utilities/"
          },
          {new Regex("SolutionReferencedProjectsLocalBasePathReplacementPattern"), @"D:/Temp/GenerateProgramArtifacts/"},
        });
      // add the argument transform
      foreach (var kvp in gPatternReplacement.GDictionary) {
        gAssemblyGroupPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      #endregion
      gAssemblyGroup = new GAssemblyGroup(gAssemblyGroupName, gPatternReplacement: gAssemblyGroupPatternReplacement);

      #region Titular AssemblyUnit
      var gAssemblyUnitName = $"{gAssemblyGroupName}";
      #region GReplacementPatternDictionary for AssemblyUnit
      gAssemblyUnitPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyUnitNameReplacementPattern"), gAssemblyUnitName}
        });
      foreach (var kvp in gAssemblyGroupPatternReplacement.GDictionary) {
        gAssemblyUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      #endregion
      gAssemblyUnit = new GAssemblyUnit(gAssemblyUnitName, gRelativePath: gAssemblyUnitName,
        gProjectUnit: new GProjectUnit(gAssemblyUnitName, gPatternReplacement: gAssemblyUnitPatternReplacement),
        gPatternReplacement: gAssemblyUnitPatternReplacement);
      #endregion
      #region Titular Base CompilationUnit
      var gCompilationUnitName = $"{gAssemblyUnitName}Base";
      #region GReplacementPatternDictionary for CompilationUnit Base CompilationUnit
      // ToDo: encapsulate and refactor
      string tempdatainitialization = @"
        /*
        #region configurationRoot for this HostedService
        // Create the configurationBuilder for this HostedService. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
        // The Environment has been configured by the GenericHost before this point is reached
        // InitialStartupDirectory has been set by the GenericHost before this point is reached, and is where the GenericHost program or service was started
        // LoadedFromDirectory has been configured by the GenericHost before this point is reached. It is the location where this assembly resides
        // ToDo: Implement these two values into the GenericHost configurationRoot somehow, then remove from the constructor signature
        // var loadedFromDirectory = hostConfiguration.GetValue<string>(\SomeStringConstantConfigrootKey\ \./\); //ToDo suport dynamic assembly loading form other Startup directories -  Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        // var initialStartupDirectory = hostConfiguration.GetValue<string>(\SomeStringConstantConfigrootKey\ \./\);
        // Build the configurationRoot for this service
        // var configurationBuilder = ConfigurationExtensions.StandardConfigurationBuilder(loadedFromDirectory, initialStartupDirectory, ConsoleMonitorDefaultConfiguration.Production, ConsoleMonitorStringConstants.SettingsFileName, ConsoleMonitorStringConstants.SettingsFileNameSuffix, StringConstants.CustomEnvironmentVariablePrefix, LoggerFactory, stringLocalizerFactory, hostEnvironment, hostConfiguration, linkedCancellationToken);
        // ConfigurationRoot = configurationBuilder.Build();
        #endregion
        // Embedded object as Data 
        //AssemblyUnitNameReplacementPatternBaseData = new AssemblyUnitNameReplacementPatternBaseData();
        */";
      gCompilationPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"},
        {new Regex("DataInitializationInStartAsyncReplacementPattern"), tempdatainitialization}, {
          new Regex("DataDisposalInStopAsyncReplacemenmtPattern"),
          "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();"
        },
      });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gCompilationPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      #endregion
      gCompilationUnit = new GCompilationUnit(gCompilationUnitName, gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gCompilationPatternReplacement);
      #region Usings For Titular Base CompilationUnit
      gUsingGroup = MUsingGroupForMicrosoftGenericHostInGHHSAndGHBS();
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      gUsingGroup = MUsingGroupForSystemGenericHostInGHHSAndGHBS();
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Namespace For Titular Base CompilationUnit
      gNamespace = new GNamespace($"{baseNamespace}.{gAssemblyGroupName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      #endregion

      #region Titular Base Class (IHostedService)
      gClass = new GClass(gCompilationUnitName, gVisibility: "public",
        gImplements: new List<string> { "IHostedService", "IDisposable" },
        gDisposesOf: new List<string> { "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle" });
      #region specific methods for IHostedService
      gClass.AddMethodGroup(CreateStartStopAsyncMethods(gAccessModifier: "virtual async"));
      #endregion
      #region Constructors
      gConstructor = new GMethod(new GMethodDeclaration(gCompilationUnitName, isConstructor: true,
        gVisibility: "public"));
      gClass.GMethods.Add(gConstructor.Philote,gConstructor);
      #endregion
      #region ConstructorGroups
      #endregion
      #region Standard Properties for every GenericHostHostedService
      #region Local ConfigurationRoot property for every GenericHostHostedService
      gClass.AddProperty(new List<GProperty>() {
        new GProperty("ConfigurationRoot", gType: "ConfigurationRoot", gAccessors: "{ get; }",
          gVisibility: "protected internal"),
      });
      #endregion
      #region Injected AutoProperty Group and their derived AutoProperty Groups for every GenericHostHostedService
      #region Injected AutoProperties whose Type IS their name
      gPropertyGroup = new GPropertyGroup("Injected AutoProperty Group for GenericHost");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in new List<string>() {
        "LoggerFactory",
        "StringLocalizerFactory",
        "HostEnvironment",
        "HostLifetime",
        "HostApplicationLifetime"
      }) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, ap, gPropertyGroupId: gPropertyGroup.Philote);
      }
      #endregion
      #region Injected AutoProperties whose Type is NOT their name
      foreach (var ap in new List<string>() { "HostConfiguration", "AppConfiguration" }) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, ap, gType: "IConfiguration",
          gPropertyGroupId: gPropertyGroup.Philote);
      }
      #endregion
      #region Derived AutoProperty Group for Logger
      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Logger");
      gClass.AddPropertyGroups(gPropertyGroup);
      gClass.AddTLoggerConstructorAutoPropertyGroup(gConstructor.Philote, gPropertyGroupId: gPropertyGroup.Philote);
      #endregion
      #region Derived AutoProperty Group for Localizers
      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Localizers");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in new List<string>() { "DebugLocalizer", "ExceptionLocalizer", "UiLocalizer" }) {
        gClass.AddTLocalizerConstructorAutoPropertyGroup(gConstructor.Philote, ap, gAssemblyUnitName,
          gPropertyGroupId: gPropertyGroup.Philote);
      }
      #endregion
      #endregion
      #endregion
      #region standard Methods for every GenericHostHostedService
      gClass.AddMethodGroup(CreateHostApplicationLifetimeEventHandlerMethods());
      #endregion
      #endregion
      gNamespace.GClasss[gClass.Philote] = gClass;
      var assemblysMainClassBase = gClass;
      #region Add a StateMachine for the service
      MStateMachineBase(gCompilationUnit, gNamespace, gClass, gConstructor);
      #endregion
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      var baseCompilationUnitName = gCompilationUnitName;
      var baseClass = gClass;
      var baseCompilationUnit = gCompilationUnit;
      /* ************************************************************************************ */
      #region Titular (Derived) CompilationUnit
      gCompilationUnitName = $"{gAssemblyUnitName}";
      gCompilationUnit = new GCompilationUnit(gCompilationUnitName, gFileSuffix: ".cs", gRelativePath: subDirectoryForGeneratedFiles,
        gPatternReplacement: gCompilationPatternReplacement);
      #region Usings For Titular CompilationUnit
      gUsingGroup = MUsingGroupForMicrosoftGenericHostInGHHSAndGHBS();
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      gUsingGroup = MUsingGroupForSystemGenericHostInGHHSAndGHBS();
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Namespace For Titular Base CompilationUnit
      gNamespace = new GNamespace($"{baseNamespace}.{gAssemblyGroupName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      #endregion
      #region Titular Class (IHostedService)
      gClass = new GClass(gCompilationUnitName, "public", gAccessModifier: "partial",
        gInheritance: baseClass.GName
      //gImplements: new List<string> { "IDisposable" },
      //gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternBaseData" }
      );
     
      gNamespace.GClasss.Add(gClass.Philote,gClass);
      #endregion
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #region ResourceUnits
      GPatternReplacement gResourcePatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("ResourceUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
        });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gResourcePatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }

      gResourceItem = new GResourceItem(gName: "ExceptionMessage1", gValue: "text for exception {0}",
        gComment: "{0} is the exception something?");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem> { [gResourceItem.Philote] = gResourceItem };
      gResourceUnit =
        new GResourceUnit("ExceptionMessages", gRelativePath: "Resources", gResourceItems: gResourceItems,
          gPatternReplacement: gResourcePatternReplacement);
      gAssemblyUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      gAssemblyUnit.GProjectUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;

      gResourceItem = new GResourceItem(gName: "Enter Selection>", gValue: "Enter Selection>",
        gComment: "Enter Selection prompt for Console UI");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem> { [gResourceItem.Philote] = gResourceItem };
      gResourceUnit = new GResourceUnit("UIMessages", gRelativePath: "Resources", gResourceItems: gResourceItems,
        gPatternReplacement: gResourcePatternReplacement);
      gAssemblyUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      gAssemblyUnit.GProjectUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      #endregion
      #region PropertyGroups for the ProjectUnit
      new List<GPropertyGroupInProjectUnit>() {
        PropertyGroupInProjectUnitForProjectUnitIsLibrary(),
        PropertyGroupInProjectUnitForPackableOnBuild(),
        PropertyGroupInProjectUnitForLifecycleStage(),
        PropertyGroupInProjectUnitForBuildConfigurations(),
        PropertyGroupInProjectUnitForVersion()
      }.ForEach(gP => gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits.Add(gP.Philote, gP));
      ;
      #endregion
      #region ItemGroups for the ProjectUnit
      var gItemGroupInProjectUnitList = MGenericHostServiceCommonItemGroupInProjectUnitList();

      gItemGroupInProjectUnitList.ForEach(o =>
        gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o));
      //_projectReferences.ForEach(o =>
      //  gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o));
      //_packageReferences.ForEach(o =>
      //  gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o));
      #endregion
      #region StringConstants Base CompilationUnit
      gCompilationPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
        });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gCompilationPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }

      #region Additional StringConstants items
      gAdditionalStatements = new List<string>() { "{dummyConfigKeyRoot,dummyConfigDefaultString}" };
      #endregion
      gCompilationUnit = CompilationUnitStringConstantsConstructor(gNamespaceName: gNamespace.GName,
        gRelativePath: subDirectoryForGeneratedFiles,
        gPatternReplacement: gCompilationPatternReplacement);
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #region DefaultConfiguration Base CompilationUnit
      gCompilationPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
        });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gCompilationPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }

      #region Additional DefaultConfiguration items
      gAdditionalStatements = new List<string>() { "{dummyConfigKeyRoot,dummyConfigDefaultString}" };
      #endregion
      gCompilationUnit = CompilationUnitDefaultConfigurationConstructor(gNamespaceName: gNamespace.GName,
        gRelativePath: subDirectoryForGeneratedFiles, gAdditionalStatements: gAdditionalStatements,
        gPatternReplacement: gCompilationPatternReplacement);
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #region Settings File(s) for Configuration
      #endregion
      gAssemblyGroup.GAssemblyUnits[gAssemblyUnit.Philote] = gAssemblyUnit;
      /* ************************************************************************************ */
      #region Interfaces
      gAssemblyUnitPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex($"AssemblyUnitNameReplacementPattern"), $"{gAssemblyGroupName}"}
      });
      foreach (var kvp in gAssemblyGroupPatternReplacement.GDictionary) {
        gAssemblyUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      gAssemblyUnitName = $"{gAssemblyGroupName}.Interfaces";
      gAssemblyUnit = new GAssemblyUnit($"{gAssemblyUnitName}",
        gRelativePath: $"{gAssemblyUnitName}",
        gProjectUnit: new GProjectUnit($"{gAssemblyUnitName}",
          gPatternReplacement: gAssemblyUnitPatternReplacement), gPatternReplacement: gAssemblyUnitPatternReplacement);

      #region Interface CompilationUnit
      gCompilationPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
      });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gCompilationPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      var compilationUnitName = $"I{baseCompilationUnitName}";
      gCompilationUnit = new GCompilationUnit($"{compilationUnitName}", gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gCompilationPatternReplacement);
      gAssemblyUnit.GCompilationUnits.Add(gCompilationUnit.Philote, gCompilationUnit);
      #region Usings For Interface CompilationUnit
      gUsingGroup = MUsingGroupForMicrosoftGenericHostInGHHSAndGHBS();
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      gUsingGroup = MUsingGroupForSystemGenericHostInGHHSAndGHBS();
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Namespace For Titular Base Interface CompilationUnit
      gNamespace = new GNamespace($"{baseNamespace}.{gAssemblyGroupName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      #endregion
      #region Titular Base Interface (IHostedService)
      var baseInterfaceName = $"I{gAssemblyGroupName}Base";
      gInterface = new GInterface(baseInterfaceName, "public");
      gNamespace.GInterfaces.Add(gInterface.Philote, gInterface);
      #endregion
      #region Titular Interface (IHostedService)
      var titularInterfaceName = $"I{gAssemblyGroupName}";
      gInterface = new GInterface(titularInterfaceName, "public", gImplements: new List<string>() {
        $"{baseInterfaceName}"
        #endregion
      });
      gNamespace.GInterfaces.Add(gInterface.Philote, gInterface);
      #endregion
      #region ProjectUnit in the Interfaces AssemblyUnit
      #region PropertyGroups for the ProjectUnit in the Interfaces AssemblyUnit
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForProjectUnitIsLibrary();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
        gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForPackableOnBuild();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
        gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForLifecycleStage();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
        gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForBuildConfigurations();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
        gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForVersion();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
        gPropertyGroupInProjectUnit;
      #endregion
      #region ItemGroups for the ProjectUnit in the Interfaces AssemblyUnit
      gItemGroupInProjectUnitList = new List<GItemGroupInProjectUnit>() {
        NetCoreGenericHostReferencesItemGroupInProjectUnit(),
        StatelessStateMachineReferencesItemGroupInProjectUnit(),
      };
      gItemGroupInProjectUnitList.ForEach(o => gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o));
      #endregion
      #endregion
      gAssemblyGroup.GAssemblyUnits.Add(gAssemblyUnit.Philote, gAssemblyUnit);
      #endregion
      return gAssemblyGroup;
    }
    public static void GAssemblyGroupGHHSFinalizer(GAssemblyGroup gAssemblyGroup) {
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
