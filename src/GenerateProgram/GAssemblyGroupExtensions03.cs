using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static GenerateProgram.GCompilationUnitExtensions;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static GenerateProgram.StringConstants;
//using AutoMapper.Configuration;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GUsingGroupExtensions;

namespace GenerateProgram {
  public static partial class GAssemblyGroupExtensions {
    public static GAssemblyGroup GAssemblyGroupGHHSConstructor(string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default,
      bool usesConsoleMonitorConvention = false) {
      //if (gAssemblyGroupName == default) {
      //  gAssemblyGroupName = "";
      //}

      GAssemblyGroup gAssemblyGroup;
      GAssemblyUnit gAssemblyUnit;
      GPatternReplacement gPatternReplacement;
      GResourceUnit gResourceUnit;
      GResourceItem gResourceItem;
      Dictionary<Philote<GResourceItem>, GResourceItem> gResourceItems;
      GCompilationUnit gCompilationUnit;
      GUsing gUsing;
      GUsingGroup gUsingGroup;
      GNamespace gNamespace;
      GClass gClass;
      GProperty gProperty;
      GPropertyGroup gPropertyGroup;
      GMethod gConstructor;
      GMethod gMethod;
      GMethodGroup gMethodGroup;
      GStatementList gAdditionalStatements;
      GInterface gInterface;
      GPropertyGroupInProjectUnit gPropertyGroupInProjectUnit;
      GItemGroupInProjectUnit gItemGroupInProjectUnit;
      GPatternReplacement gAssemblyGroupPatternReplacement;
      GPatternReplacement gAssemblyUnitPatternReplacement;
      GPatternReplacement gCompilationPatternReplacement;

      //var gAssemblyGroupName = "AssemblyGroupNameReplacementPattern";
      #region GReplacementPatternDictionary for AssemblyGroup
      gAssemblyGroupPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyGroupNameReplacementPattern"), gAssemblyGroupName}, {
            new Regex("SolutionReferencedProjectsBasePathReplacementPattern"),
            @"C:/Dropbox/whertzing/GitHub/ATAP.Utilities/"
          },
        });
      #endregion
      gAssemblyGroup = new GAssemblyGroup(gAssemblyGroupName, gPatternReplacement: gAssemblyGroupPatternReplacement);

      #region TitularAssemblyUnit
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
      gAssemblyUnit = new GAssemblyUnit($"{gAssemblyUnitName}", gRelativePath: $"{gAssemblyUnitName}",
        gProjectUnit: new GProjectUnit($"{gAssemblyUnitName}", gPatternReplacement: gAssemblyUnitPatternReplacement),
        gPatternReplacement: gAssemblyUnitPatternReplacement);
      #endregion
      #region TitularCompilationUnit Base CompilationUnit
      var gCompilationUnitName = $"{assemblyUnitName}Base";
      #region GReplacementPatternDictionary for CompilationUnit Base CompilationUnit
      gCompilationPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"},
        {new Regex("DataInitializationInStartAsyncReplacementPattern"), "Choices=new List<string>() {\"Choice1\"};"}, {
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
      #region Usings For TitularCompilationUnit Base CompilationUnit
      gUsingGroup = UsingsForMicrosoftGenericHost();
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;

      gUsingGroup = new GUsingGroup("Usings For System");
      foreach (var gName in new List<string>() {
        "System",
        "System.Collections.Generic",
        "System.IO",
        "System.Text",
        "System.Threading",
        "System.Threading.Tasks",
        "System.Diagnostics",
        "System.Globalization",
        "System.Linq"
      }) {
        gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      if (usesConsoleMonitorConvention) {
        gUsingGroup = UsingsForConsoleMonitorPattern($"{baseNamespace}");
        gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      }
      #endregion
      #region namespace For TitularCompilationUnit Base CompilationUnit
      gNamespace = new GNamespace($"{baseNamespace}.{gAssemblyGroupName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      #endregion

      #region TitularClass Base Class (IHostedService)
      gClass = new GClass(gCompilationUnitName, gVisibility: "public",
        gImplements: new List<string> {"IHostedService", "IDisposable"},
        gDisposesOf: new List<string> {"SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle"});
      #region specific methods for IHostedService
      gClass.AddMethodGroup(CreateStartStopAsyncMethods(usesConsoleMonitorConvention));
      #endregion
      #region Constructors
      gConstructor = new GMethod(new GMethodDeclaration(gCompilationUnitName, isConstructor: true,
        gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;
      #endregion
      #region ConstructorGroups
      #endregion
      #region Propertys for services that follow the ConsoleMonitor pattern
      if (usesConsoleMonitorConvention) {
        gClass.AddProperty(new List<GProperty>() {
          new GProperty("Choices", gType: "Dictionary<String,IEnumerable<string>>", gAccessors: "{ get; }",
            gVisibility: "protected internal"),
          new GProperty("SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle", gType: "IDisposable",
            gAccessors: "{ get; set; }", gVisibility: "protected internal"),
          new GProperty("StdInHandlerState", gType: "String", gAccessors: "{ get; }", gVisibility: "protected internal")
        });
      }
      #endregion
      #region Standard Properties for every GenericHostHostedService
      #region local ConfigurationRoot property for every GenericHostHostedService
      gClass.AddProperty(new List<GProperty>() {
        new GProperty("ConfigurationRoot", gType: "ConfigurationRoot", gAccessors: "{ get; }",
          gVisibility: "protected internal"),
      });
      #endregion
      #region Injected AutoProperty Group and their derived AutoProperties for GenericHost
      #region InjectedAutoProperties whose Type IS their name
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
      #region InjectedAutoProperties whose Type is NOT their name
      foreach (var ap in new List<string>() {"HostConfiguration", "AppConfiguration"}) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, ap, gType: "IConfiguration",
          gPropertyGroupId: gPropertyGroup.Philote);
      }
      #endregion
      #region Derived AutoProperty Group for Logger
      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Logger");
      gClass.AddPropertyGroups(gPropertyGroup);
      gClass.AddTLoggerConstructorAutoPropertyGroup(gConstructor.Philote, gPropertyGroupId: gPropertyGroup.Philote);
      #endregion
      #region Derived AutoProperties for Localizers
      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Localizers");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in new List<string>() {"DebugLocalizer", "ExceptionLocalizer", "UiLocalizer"}) {
        gClass.AddTLocalizerConstructorAutoPropertyGroup(gConstructor.Philote, ap, assemblyUnitName,
          gPropertyGroupId: gPropertyGroup.Philote);
      }
      #endregion
      #endregion
      #region Injected Properties for services that follow the ConsoleMonitor pattern
      if (usesConsoleMonitorConvention) {
        gPropertyGroup = new GPropertyGroup("ConsoleMonitor pattern supporting injected HostedServices");
        gClass.AddPropertyGroups(gPropertyGroup);
        foreach (var ap in new List<string>() {"ConsoleMonitorGenericHostHostedService"}) {
          gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, ap, gPropertyGroupId: gPropertyGroup.Philote);
        }
      }
      #endregion
      #endregion
      #region standard Methods for every GenericHostHostedService
      gClass.AddMethodGroup(CreateHostApplicationLifetimeEventHandlerMethods());
      #endregion
      #region standard methods for any GenericHostHostedService that follows the ConsoleMonitor convention for data in and data out
      if (usesConsoleMonitorConvention) {
        gClass.AddMethodGroup(CreateUsesConsoleMonitorMethods());
      }
      #endregion
      #endregion
      gNamespace.GClasss[gClass.Philote] = gClass;
      var baseClass = gClass;
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #region TitularCompilationUnit (non-Base) CompilationUnit
      gCompilationUnit = new GCompilationUnit("CompilationUnitNameReplacementPattern", gFileSuffix: ".cs",
        gPatternReplacement: gCompilationPatternReplacement);
      gUsingGroup = new GUsingGroup("Usings For System");
      foreach (var gName in new List<string>() {
        "System",
        "System.Collections.Generic",
        "System.IO",
        "System.Text",
        "System.Threading",
        "System.Threading.Tasks",
        "System.Diagnostics",
        "System.Globalization",
        "System.Linq"
      }) {
        gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      gNamespace = new GNamespace($"{baseNamespace}.CompilationUnitNameReplacementPattern");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      #region TitularClass (non-base) (IHostedService)
      gClass = new GClass("CompilationUnitNameReplacementPattern", "public", gAccessModifier: "partial",
        gInheritance: "CompilationUnitNameReplacementPatternBase"
        //gImplements: new List<string> { "IDisposable" },
        //gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternBaseData" }
      );
      GStatementList gStatementList = new GStatementList();

      if (usesConsoleMonitorConvention) {
        // State initialization
        gStatementList.GStatements.AddRange(new List<string>() {
          "var ConsoleMonitorStateMachine = new StateMachine<State, Trigger>(State.NotConnected);"
        });
      }
      var gMethodBody = new GMethodBody(gStatementList);
      gConstructor = new GMethod(new GMethodDeclaration("CompilationUnitNameReplacementPattern", isConstructor: true,
        gVisibility: "public", gBase: " "), gMethodBody);
      gClass.GConstructors[gConstructor.Philote] = gConstructor;
      gNamespace.GClasss[gClass.Philote] = gClass;
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
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem> {[gResourceItem.Philote] = gResourceItem};
      gResourceUnit =
        new GResourceUnit("ExceptionMessages", gRelativePath: "Resources", gResourceItems: gResourceItems,
          gPatternReplacement: gResourcePatternReplacement);
      gAssemblyUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      gAssemblyUnit.GProjectUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;

      gResourceItem = new GResourceItem(gName: "Enter Selection>", gValue: "Enter Selection>",
        gComment: "Enter Selection prompt for Console UI");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem> {[gResourceItem.Philote] = gResourceItem};
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
      var gItemGroupInProjectUnitList = new List<GItemGroupInProjectUnit>() {
        ProjectReferenceItemGroupInProjectUnitForLoggingUtilities(),
        ItemGroupInProjectUnitForSerilogAndSeqMELLoggingProviderPackageReferences(),
        ItemGroupInProjectUnitForSerilogLoggingProviderPackageReferences(),
        ItemGroupInProjectUnitForQuickGraphPackageReferences(),
        ItemGroupInProjectUnitForQuickGraphDependentPackageReferences(),
        ItemGroupInProjectUnitForReactiveExtensionsPackageReferences(),
        ItemGroupInProjectUnitForServiceStackSerializationPackageReferences(),
        ItemGroupInProjectUnitForServiceStackORMLitePackageReferences(),
        ProjectReferenceItemGroupInProjectUnitForPersistenceUtilities(),
        ItemGroupInProjectUnitForNetCoreGenericHostAndWebServerHostPackageReferences(),
        ProjectReferenceItemGroupInProjectUnitForGenericHostUtilities(),
        ProjectReferenceItemGroupInProjectUnitForTimersService(),
        ItemGroupInProjectUnitForStatelessStatemachinePackageReferences(),
        //ProjectReferenceItemGroupInProjectUnitForFilesystemWatchersService(),
        ItemGroupInProjectUnitForILWeavingUsingFodyPackageReferences()
      };
      if (usesConsoleMonitorConvention) {
        gItemGroupInProjectUnitList.Add(ProjectReferenceItemGroupInProjectUnitForConsoleMonitorPattern());
      }
      gItemGroupInProjectUnitList.ForEach(gP =>
        gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gP.Philote, gP));
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
      gAdditionalStatements = new GStatementList(new List<string>() {"{dummyConfigKeyRoot,dummyConfigDefaultString}"});
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
      gAdditionalStatements = new GStatementList(new List<string>() {"{dummyConfigKeyRoot,dummyConfigDefaultString}"});
      #endregion
      gCompilationUnit = CompilationUnitDefaultConfigurationConstructor(gNamespaceName: gNamespace.GName,
        gRelativePath: subDirectoryForGeneratedFiles, gAdditionalStatements: gAdditionalStatements,
        gPatternReplacement: gCompilationPatternReplacement);
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion

      gAssemblyGroup.GAssemblyUnits[gAssemblyUnit.Philote] = gAssemblyUnit;

      #region TitularAssemblyUnitName Interfaces
      gAssemblyGroupName = "AssemblyGroupNameReplacementPattern";
      gAssemblyUnitPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex($"AssemblyUnitNameReplacementPattern"), $"{gAssemblyGroupName}"}
      });
      foreach (var kvp in gAssemblyGroupPatternReplacement.GDictionary) {
        gAssemblyUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      gAssemblyUnitName = $"{gAssemblyGroupName}";
      gAssemblyUnit = new GAssemblyUnit($"{gAssemblyUnitName}.Interfaces",
        gRelativePath: $"{gAssemblyGroupName}.Interfaces",
        gProjectUnit: new GProjectUnit($"{gAssemblyUnitName}.Interfaces",
          gPatternReplacement: gAssemblyUnitPatternReplacement), gPatternReplacement: gAssemblyUnitPatternReplacement);

      #region TitularCompilationUnitName Base Interfaces
      gCompilationPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
      });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gCompilationPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      var compilationUnitName = $"{assemblyUnitName}";
      gCompilationUnit = new GCompilationUnit($"{compilationUnitName}Base.Interfaces", gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gCompilationPatternReplacement);
      gUsingGroup = UsingsForMicrosoftGenericHost();
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      foreach (var gName in new List<string>() {"System", "System.Collections.Generic", "System.IO"}) {
        gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      gNamespace = new GNamespace($"{baseNamespace}.{compilationUnitName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      //gInterface = new GInterface($"I{compilationUnitName}Base");
      //gCompilationUnit.GNamespaces[gNamespace.Philote].GInterfaces[gInterface.Philote] = gInterface;

      gInterface = new GInterface($"I{compilationUnitName}");
      foreach (var kvp in baseClass.ConvertToInterfacePropertys()) {
        gInterface.GPropertys.Add(kvp.Key, kvp.Value);
      }

      //baseClass.ConvertToInterfacePropertyGroups().ForEach(x => gInterface.GPropertyGroups.Add(x.Key, x.Value));
      foreach (var kvp in baseClass.ConvertToInterfaceMethods()) {
        gInterface.GMethods.Add(kvp.Key, kvp.Value);
      }

      //baseClass.ConvertToInterfaceMethodGroups().ForEach(x => gInterface.GMethodGroups.Add(x.Key, x.Value));
      //baseClass.ConvertToInterfaceExceptions().ForEach(x => gInterface.GExceptions.Add(x.Key, x.Value));
      //baseClass.ConvertToInterfaceExceptionGroups().ForEach(x => gInterface.GExceptionGroups.Add(x.Key, x.Value));
      //baseClass.ConvertToInterfaceEvents().ForEach(x => gInterface.GEvents.Add(x.Key, x.Value));
      //baseClass.ConvertToInterfaceEventGroups().ForEach(x => gInterface.GEventGroups.Add(x.Key, x.Value));
      gCompilationUnit.GNamespaces[gNamespace.Philote].GInterfaces[gInterface.Philote] = gInterface;
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #endregion

      #region ProjectUnit
      #region PropertyGroups for the ProjectUnit Interfaces
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
      #region ItemGroups for the ProjectUnit Interfaces
      gItemGroupInProjectUnitList = new List<GItemGroupInProjectUnit>() {
        ProjectReferenceItemGroupInProjectUnitForLoggingUtilities(),
        ItemGroupInProjectUnitForSerilogAndSeqMELLoggingProviderPackageReferences(),
        ItemGroupInProjectUnitForSerilogLoggingProviderPackageReferences(),
        ItemGroupInProjectUnitForQuickGraphPackageReferences(),
        ItemGroupInProjectUnitForQuickGraphDependentPackageReferences(),
        ItemGroupInProjectUnitForReactiveExtensionsPackageReferences(),
        ItemGroupInProjectUnitForServiceStackSerializationPackageReferences(),
        ItemGroupInProjectUnitForServiceStackORMLitePackageReferences(),
        ProjectReferenceItemGroupInProjectUnitForPersistenceUtilities(),
        ItemGroupInProjectUnitForNetCoreGenericHostAndWebServerHostPackageReferences(),
        ProjectReferenceItemGroupInProjectUnitForGenericHostUtilities(),
        ItemGroupInProjectUnitForStatelessStatemachinePackageReferences(),
        ProjectReferenceItemGroupInProjectUnitForTimersService(),
        //ProjectReferenceItemGroupInProjectUnitForFilesystemWatchersService(),
        ItemGroupInProjectUnitForILWeavingUsingFodyPackageReferences()
      };
      if (usesConsoleMonitorConvention) {
        gItemGroupInProjectUnitList.Add(ProjectReferenceItemGroupInProjectUnitForConsoleMonitorPattern());
      }
      gItemGroupInProjectUnitList.ForEach(gP =>
        gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gP.Philote, gP));
      #endregion
      #endregion

      gAssemblyGroup.GAssemblyUnits[gAssemblyUnit.Philote] = gAssemblyUnit;

      return gAssemblyGroup;
    }
  }
}
