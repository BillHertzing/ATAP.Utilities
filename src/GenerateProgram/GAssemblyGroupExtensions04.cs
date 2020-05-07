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

    public static GAssemblyGroup GAssemblyGroupGHBSConstructor(string gAssemblyGroupName = default, string subDirectoryForGeneratedFiles = default, string baseNamespace = default, bool usesConsoleMonitorConvention = false) {
      if (gAssemblyGroupName == default) {
        gAssemblyGroupName = "";
      }

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

      var gAassemblyGroupName = "AssemblyGroupNameReplacementPattern";
      #region GReplacementPatternDictionary for AssemblyGroup
      GPatternReplacement gAssemblyGroupPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyGroupNameReplacementPattern"), gAssemblyGroupName},
          {new Regex("SolutionReferencedProjectsBasePathReplacementPattern"),
            @"C:/Dropbox/whertzing/GitHub/ATAP.Utilities/"
          },
        });
      #endregion
      gAssemblyGroup = new GAssemblyGroup(gAssemblyGroupName, gPatternReplacement: gAssemblyGroupPatternReplacement);

      #region TitularAssemblyUnit
      var gAssemblyUnitName = $"{gAassemblyGroupName}";
      #region GReplacementPatternDictionary for AssemblyUnit
      GPatternReplacement gAssemblyUnitPatternReplacement = new GPatternReplacement(
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
      GPatternReplacement gCompilationPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"},
        {new Regex("DataInitializationInStartAsyncReplacementPattern"), "Choices=new List<string>() {\"Choice1\"};"},
        {new Regex("DataDisposalInStopAsyncReplacemenmtPattern"), "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();"},
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
        "System","System.Collections.Generic","System.IO","System.Text","System.Threading",
        "System.Threading.Tasks","System.Diagnostics","System.Globalization","System.Linq"
      }) {
        gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      #endregion
      #region namespace For TitularCompilationUnit Base CompilationUnit
      gNamespace = new GNamespace($"{baseNamespace}.{gAassemblyGroupName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      #endregion

      #region TitularClass Base Class (IHostedService)
      gClass = new GClass(gCompilationUnitName, gVisibility: "public",
        gInheritance: "BackgroundService",
        gImplements: new List<string> {  "IDisposable" },
        gDisposesOf: new List<string> { "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle" });
      #region specific methods for BackgroundService
      gClass.AddMethod(CreateExecuteAsyncMethod());
      #endregion
      #region Constructors
      gConstructor = new GMethod(new GMethodDeclaration(gCompilationUnitName, isConstructor: true,
        gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;
      #endregion
      #region ConstructorGroups
      #endregion
      #region Propertys for services that follow the ConsoleMonitor pattern
      gClass.AddProperty(new List<GProperty>() {
       new GProperty("Choices", gType: "Dictionary<String,IEnumerable<string>>", gAccessors: "{ get; }", gVisibility:"protected internal"),
       new GProperty("SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle", gType: "IDisposable", gAccessors: "{ get; set; }", gVisibility:"protected internal"),
       new GProperty("StdInHandlerState", gType: "String", gAccessors: "{ get; }", gVisibility:"protected internal")
      });
      #endregion
      #region Standard Properties for every GenericHostHostedService
      #region local ConfigurationRoot property for every GenericHostHostedService
      new List<GProperty>() {
             new GProperty("ConfigurationRoot", gType:"ConfigurationRoot", gAccessors: "{ get; }", gVisibility:"protected internal"),
      }.ForEach(gProperty => gClass.GPropertys[gProperty.Philote] = gProperty);
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
      #region Derived AutoProperties for Localizers
      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Localizers");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in new List<string>() { "DebugLocalizer", "ExceptionLocalizer", "UiLocalizer" }) {
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
      gConstructor = new GMethod(new GMethodDeclaration("CompilationUnitNameReplacementPattern", isConstructor: true,
        gVisibility: "public", gBase: "ToDo:base arguments"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;
      gNamespace.GClasss[gClass.Philote] = gClass;
      #endregion
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #region ResourceUnits
      GPatternReplacement gResourcePatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("ResourceUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
      });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gResourcePatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }

      gResourceItem = new GResourceItem(gName: "ExceptionMessage1", gValue: "text for exception {0}",
        gComment: "{0} is the exception something?");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem>();
      gResourceItems[gResourceItem.Philote] = gResourceItem;
      gResourceUnit =
        new GResourceUnit("ExceptionMessages", gRelativePath: "Resources", gResourceItems: gResourceItems, gPatternReplacement: gResourcePatternReplacement);
      gAssemblyUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      gAssemblyUnit.GProjectUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;

      gResourceItem = new GResourceItem(gName: "Enter Selection>", gValue: "Enter Selection>",
        gComment: "Enter Selection prompt for Console UI");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem>();
      gResourceItems[gResourceItem.Philote] = gResourceItem;
      gResourceUnit = new GResourceUnit("UIMessages", gRelativePath: "Resources", gResourceItems: gResourceItems, gPatternReplacement: gResourcePatternReplacement);
      gAssemblyUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      gAssemblyUnit.GProjectUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      #endregion
      #region PropertyGroups for the ProjectUnit
      new List<GPropertyGroupInProjectUnit>() {
        PropertyGroupInProjectUnitForProjectUnitIsLibrary(), PropertyGroupInProjectUnitForPackableOnBuild(),PropertyGroupInProjectUnitForLifecycleStage(),
        PropertyGroupInProjectUnitForBuildConfigurations(), PropertyGroupInProjectUnitForVersion()
      }.ForEach(gP => gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits.Add(gP.Philote, gP)); ;
      #endregion
      #region ItemGroups for the ProjectUnit
      new List<GItemGroupInProjectUnit>() {
        ProjectReferenceItemGroupInProjectUnitForLoggingUtilities(), ItemGroupInProjectUnitForSerilogAndSeqMELLoggingProviderPackageReferences(),ItemGroupInProjectUnitForSerilogLoggingProviderPackageReferences(),
        ProjectReferenceItemGroupInProjectUnitForConsoleServices(),
        ItemGroupInProjectUnitForQuickGraphPackageReferences(), ItemGroupInProjectUnitForQuickGraphDependentPackageReferences(),
        ItemGroupInProjectUnitForReactiveExtensionsPackageReferences(),ItemGroupInProjectUnitForServiceStackSerializationPackageReferences(),
        ItemGroupInProjectUnitForServiceStackORMLitePackageReferences(),
        ProjectReferenceItemGroupInProjectUnitForPersistenceUtilities(),
        ItemGroupInProjectUnitForNetCoreGenericHostAndWebServerHostPackageReferences(), ProjectReferenceItemGroupInProjectUnitForGenericHostUtilities(),
        ProjectReferenceItemGroupInProjectUnitForTimersService(),
        //ProjectReferenceItemGroupInProjectUnitForFilesystemWatchersService(),
        ItemGroupInProjectUnitForILWeavingUsingFodyPackageReferences()
      }.ForEach(gP => gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gP.Philote, gP)); ;
      #endregion
      #region StringConstants Base CompilationUnit
      #region Additional StringConstants items
       gAdditionalStatements = new GStatementList(new List<string>(){"{dummyConfigKeyRoot,dummyConfigDefaultString}"});
      #endregion
      gCompilationUnit = CompilationUnitStringConstantsConstructor(gNamespaceName: gNamespace.GName,
        gRelativePath: subDirectoryForGeneratedFiles,
        gPatternReplacement: gAssemblyUnit.GPatternReplacement);
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #region DefaultConfiguration Base CompilationUnit
      #region Additional DefaultConfiguration items
       gAdditionalStatements = new GStatementList(new List<string>(){"{dummyConfigKeyRoot,dummyConfigDefaultString}"});
      #endregion
      gCompilationUnit = CompilationUnitDefaultConfigurationConstructor(gNamespaceName: gNamespace.GName,
        gRelativePath: subDirectoryForGeneratedFiles,gAdditionalStatements:gAdditionalStatements, gPatternReplacement: gAssemblyUnit.GPatternReplacement);
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion

      gAssemblyGroup.GAssemblyUnits[gAssemblyUnit.Philote] = gAssemblyUnit;

      #region TitularAssemblyUnitName Interfaces

      gAassemblyGroupName = "AssemblyGroupNameReplacementPattern";
      gAssemblyUnitPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex($"AssemblyUnitNameReplacementPattern"), $"{gAassemblyGroupName}"}
      });
      foreach (var kvp in gAssemblyGroupPatternReplacement.GDictionary) {
        gAssemblyUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      gAssemblyUnitName = $"{gAassemblyGroupName}";
      gAssemblyUnit = new GAssemblyUnit($"{gAssemblyUnitName}.Interfaces", gRelativePath: $"{gAassemblyGroupName}.Interfaces",
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
      foreach (var gName in new List<string>() {
        "System",
        "System.Collections.Generic",
        "System.IO"
      }) {
        gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      gNamespace = new GNamespace($"{baseNamespace}.{compilationUnitName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      //gInterface = new GInterface($"I{compilationUnitName}Base");
      //gCompilationUnit.GNamespaces[gNamespace.Philote].GInterfaces[gInterface.Philote] = gInterface;

      gInterface = new GInterface($"I{compilationUnitName}");
      foreach (var kvp in baseClass.ConvertToInterfacePropertys()) { gInterface.GPropertys.Add(kvp.Key, kvp.Value); }
      //baseClass.ConvertToInterfacePropertyGroups().ForEach(x => gInterface.GPropertyGroups.Add(x.Key, x.Value));
      foreach (var kvp in baseClass.ConvertToInterfaceMethods()) { gInterface.GMethods.Add(kvp.Key, kvp.Value); }
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
      #region PropertyGroups for the ProjectUnit
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
      #region ItemGroups for the ProjectUnit
      new List<GItemGroupInProjectUnit>() {
        ProjectReferenceItemGroupInProjectUnitForLoggingUtilities(), ItemGroupInProjectUnitForSerilogAndSeqMELLoggingProviderPackageReferences(),ItemGroupInProjectUnitForSerilogLoggingProviderPackageReferences(),
        ProjectReferenceItemGroupInProjectUnitForConsoleServices(),
        ItemGroupInProjectUnitForQuickGraphPackageReferences(), ItemGroupInProjectUnitForQuickGraphDependentPackageReferences(),
        ItemGroupInProjectUnitForReactiveExtensionsPackageReferences(),ItemGroupInProjectUnitForServiceStackSerializationPackageReferences(),
        ItemGroupInProjectUnitForServiceStackORMLitePackageReferences(),
        ProjectReferenceItemGroupInProjectUnitForPersistenceUtilities(),
        ItemGroupInProjectUnitForNetCoreGenericHostAndWebServerHostPackageReferences(), ProjectReferenceItemGroupInProjectUnitForGenericHostUtilities(),
        ProjectReferenceItemGroupInProjectUnitForTimersService(),
        //ProjectReferenceItemGroupInProjectUnitForFilesystemWatchersService(),
        ItemGroupInProjectUnitForILWeavingUsingFodyPackageReferences()
      }.ForEach(gP => gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gP.Philote, gP)); ;
      #endregion
      #endregion

      gAssemblyGroup.GAssemblyUnits[gAssemblyUnit.Philote] = gAssemblyUnit;

      return gAssemblyGroup;
    }
  }
}
//gUsing = new GUsing("StandaloneUsing1");
//gCompilationUnit.GUsings[gUsing.Philote] = gUsing;
//gUsing = new GUsing("StandaloneUsing2");
//gCompilationUnit.GUsings[gUsing.Philote] = gUsing;

//gClass.AddPropertys(new GProperty("SoloProperty", "String"));

//var gPropertys = new List<GProperty>()  {
//          new GProperty("SoloProperty1OfCollection","String"),
//          new GProperty("SoloProperty2OfCollection","String")
//      };
//gClass.AddPropertys(gPropertys);
//var gPropertyGroup = new GPropertyGroup("PropertyGroup1", new List<GProperty>{
//        new GProperty("Property1OfPropertyGroup1","String"),
//        new GProperty("Property2OfPropertyGroup1","String")
//      });
//gClass.AddPropertyGroups(gPropertyGroup);
//var gPropertyGroups = new List<GPropertyGroup>() {
//        new GPropertyGroup("PropertyGroup2", new List<GProperty>{
//          new GProperty("Property1OfPropertyGroup2","String"),
//          new GProperty("Property2OfPropertyGroup2","String")
//        }),
//        new GPropertyGroup("PropertyGroup3", new List<GProperty>{
//          new GProperty("Property1OfPropertyGroup3","String"),
//          new GProperty("Property2OfPropertyGroup3","String")
//        })
//      };
//gClass.AddPropertyGroups(gPropertyGroups);
//GMethodArgument arg1 = new GMethodArgument("arg1", "int");
//GMethodArgument arg2 = new GMethodArgument("arg2", "string", isOut: true);
//GMethodArgument arg3 = new GMethodArgument("arg3", "Philote<GMethodArgument>", isRef: true);
//Dictionary<Philote<GMethodArgument>, GMethodArgument> gMethodArguments =
//  new Dictionary<Philote<GMethodArgument>, GMethodArgument>() { { arg1.Philote, arg1 }, { arg2.Philote, arg2 }, { arg3.Philote, arg3 } };
//GMethodDeclaration gMethodDeclaration =
//  new GMethodDeclaration(gName: "ServiceData", isConstructor:true,gMethodArguments:gMethodArguments);
//GMethodBody gMethodBody = new GMethodBody(statementList: new List<string>() { "A=a", "B=b" });
//var gConstructor = new GMethod(gMethodDeclaration, gMethodBody);

//gCompilationUnits = new Dictionary<Philote<GCompilationUnit>, GCompilationUnit>();
//gCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
