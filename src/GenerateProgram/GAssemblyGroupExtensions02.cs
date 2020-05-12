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
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GUsingGroupExtensions;
namespace GenerateProgram {

  public static partial class GAssemblyGroupExtensions {

    public static GAssemblyGroup GAssemblyGroupGHBSWithEmbeddedDataConstructor(string gAssemblyGroupName = default, string subDirectoryForGeneratedFiles = default,
      string baseNamespace = default,
      bool usesConsoleMonitorConvention = false) {
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
      GInterface gInterface;

      GPropertyGroupInProjectUnit gPropertyGroupInProjectUnit;
      GItemGroupInProjectUnit gItemGroupInProjectUnit;

      var assemblyGroupName = "AssemblyGroupNameReplacementPattern";
      GPatternReplacement gAssemblyGroupPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyGroupNameReplacementPattern"), gAssemblyGroupName},
          {new Regex("SolutionReferencedProjectsBasePathReplacementPattern"),
            @"C:/Dropbox/whertzing/GitHub/ATAP.Utilities/"
          },
          {new Regex("SolutionReferencedProjectsLocalBasePathReplacementPattern"), @"D:/Temp/GenerateProgramArtifacts/"},
        });
      gAssemblyGroup = new GAssemblyGroup(gAssemblyGroupName, gPatternReplacement: gAssemblyGroupPatternReplacement);
      #region TitularAssemblyUnit
      GPatternReplacement gAssemblyUnitPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
        {new Regex("AssemblyUnitNameReplacementPattern"), "AssemblyGroupNameReplacementPattern"}
      });
      foreach (var kvp in gAssemblyGroupPatternReplacement.GDictionary) {
        gAssemblyUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      var assemblyUnitName = $"{assemblyGroupName}";
      gAssemblyUnit = new GAssemblyUnit($"{assemblyUnitName}", gRelativePath: $"{assemblyUnitName}",
        gProjectUnit: new GProjectUnit($"{assemblyUnitName}",gPatternReplacement: gAssemblyUnitPatternReplacement),
          
        gPatternReplacement: gAssemblyUnitPatternReplacement);

      #region TitularCompilationUnit With Embedded Data Base Class
      GPatternReplacement gCompilationPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
      });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gCompilationPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      gCompilationUnit = new GCompilationUnit("CompilationUnitNameReplacementPatternBase", gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gCompilationPatternReplacement);

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

      gNamespace = new GNamespace($"{baseNamespace}.CompilationUnitNameReplacementPattern");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;

      #region embedded Data Class generated Base

      gClass = new GClass("CompilationUnitNameReplacementPatternBaseData", "public",
        gImplements: new List<string> { "IDisposable" },
        gDisposesOf: new List<string> { "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle" });
      gConstructor = new GMethod(new GMethodDeclaration("CompilationUnitNameReplacementPatternBaseData", isConstructor: true,
        gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;

      new List<GProperty>() {
        new GProperty("ConfigurationRoot", gType:"ConfigurationRoot", gAccessors: "{ get; }", gVisibility:"protected internal"),
        new GProperty("Choices", gType: "IEnumerable<string>", gAccessors: "{ get; }", gVisibility:"protected internal"),
        new GProperty("SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle", gType: "IDisposable",
          gAccessors: "{ get; }", gVisibility:"protected internal"),
        new GProperty("StdInHandlerState", gType: "StringBuilder", gAccessors: "{ get; }", gVisibility:"protected internal")
      }.ForEach(gProperty => gClass.GPropertys[gProperty.Philote] = gProperty);
      gNamespace.GClasss[gClass.Philote] = gClass;

      #endregion

      #region TitularClass generated Base

      gClass = new GClass("CompilationUnitNameReplacementPatternBase", "public",
        gInheritance: "BackgroundService",
        gImplements: new List<string> { "IDisposable" },
        gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternBaseData" });
      gClass.AddMethod(CreateExecuteAsyncMethod());

      gConstructor = new GMethod(new GMethodDeclaration("CompilationUnitNameReplacementPatternBase", isConstructor: true,
        gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;

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

      foreach (var ap in new List<string>() { "HostConfiguration", "AppConfiguration" }) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, ap, gType: "IConfiguration",
          gPropertyGroupId: gPropertyGroup.Philote);
      }

      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Logger");
      gClass.AddPropertyGroups(gPropertyGroup);
      gClass.AddTLoggerConstructorAutoPropertyGroup(gConstructor.Philote, gPropertyGroupId: gPropertyGroup.Philote);

      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Localizers");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in new List<string>() { "DebugLocalizer", "ExceptionLocalizer", "UiLocalizer" }) {
        gClass.AddTLocalizerConstructorAutoPropertyGroup(gConstructor.Philote, ap, assemblyUnitName,
          gPropertyGroupId: gPropertyGroup.Philote);
      }

      // For classes with embedded Data object as a public Property
      gProperty = new GProperty(gName: "CompilationUnitNameReplacementPatternBaseData", gType: "CompilationUnitNameReplacementPatternBaseData", gVisibility: "public");
      gClass.GPropertys[gProperty.Philote] = gProperty;
      // Else add all the Data properties , grouped if desired, to the gClass here



      gClass.AddMethodGroup(CreateHostApplicationLifetimeEventHandlerMethods());

      gNamespace.GClasss[gClass.Philote] = gClass;
      var baseClass = gClass;
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;

      #region non-Base code
      #region non-base compilationUnit declaration
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
      #endregion
      #region non-base embedded Data class
      gClass = new GClass("CompilationUnitNameReplacementPatternData", "public", gAccessModifier: "partial",
        gInheritance: $"CompilationUnitNameReplacementPatternBaseData", gImplements: new List<string> { "IDisposable" });
      gConstructor = new GMethod(new GMethodDeclaration("CompilationUnitNameReplacementPatternData", isConstructor: true,
        gBase: "ToDo:base arguments", gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;
      gNamespace.GClasss[gClass.Philote] = gClass;
      #endregion
      #region non-base TitularClass
      gClass = new GClass("CompilationUnitNameReplacementPattern", "public", gAccessModifier: "partial",
        gInheritance: "CompilationUnitNameReplacementPatternBase",
        gImplements: new List<string> { "IDisposable" },
        gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternBaseData" });
      gConstructor = new GMethod(new GMethodDeclaration("CompilationUnitNameReplacementPattern", isConstructor: true,
        gVisibility: "public", gBase: "ToDo:base arguments"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;
      gNamespace.GClasss[gClass.Philote] = gClass;
      #endregion
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #endregion
      #endregion

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

      #region PropertyGroups for the ProjectUnit
      new List<GPropertyGroupInProjectUnit>() {
        PropertyGroupInProjectUnitForProjectUnitIsLibrary(), PropertyGroupInProjectUnitForPackableOnBuild(),PropertyGroupInProjectUnitForLifecycleStage(),
        PropertyGroupInProjectUnitForBuildConfigurations(), PropertyGroupInProjectUnitForVersion()
      }.ForEach(gP => gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits.Add(gP.Philote, gP)); ;
      #endregion

      #region ItemGroups for the ProjectUnit
      var gItemGroupInProjectUnitList = new List<GItemGroupInProjectUnit>() {
        ProjectReferenceItemGroupInProjectUnitForLoggingUtilities("SolutionReferencedProjectsBasePathReplacementPattern"),
        SerilogAndSeqMELLoggingProviderPackageReferencesItemGroupInProjectUnit(),
        SerilogLoggingProviderPackageReferencesItemGroupInProjectUnit(),
        QuickGraphPackageReferencesItemGroupInProjectUnit(),
        QuickGraphDependentPackageReferencesItemGroupInProjectUnit(),
        ReactiveExtensionsPackageReferencesItemGroupInProjectUnit(),
        ServiceStackSerializationPackageReferencesItemGroupInProjectUnit(),
        ServiceStackORMLitePackageReferencesItemGroupInProjectUnit(),
        ProjectReferenceItemGroupInProjectUnitForPersistenceUtilities("SolutionReferencedProjectsBasePathReplacementPattern"),
        NetCoreGenericHostAndWebServerHostPackageReferencesItemGroupInProjectUnit(),
        ProjectReferenceItemGroupInProjectUnitForGenericHostUtilities("SolutionReferencedProjectsBasePathReplacementPattern"),
        ProjectReferenceItemGroupInProjectUnitForTimersService("SolutionReferencedProjectsBasePathReplacementPattern"),
        //ProjectReferenceItemGroupInProjectUnitForFilesystemWatchersService(),
        ItemGroupInProjectUnitForILWeavingUsingFodyPackageReferences()
      };
      if (usesConsoleMonitorConvention) {
        gItemGroupInProjectUnitList.Add(ProjectReferenceItemGroupInProjectUnitForConsoleMonitorPattern("SolutionReferencedProjectsBasePathReplacementPattern"));
      }
      gItemGroupInProjectUnitList.ForEach(gP => gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gP.Philote, gP));
      #endregion
      #region region StringConstantsBase
      gCompilationUnit = CompilationUnitStringConstantsConstructor(gNamespaceName: gNamespace.GName,
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gAssemblyUnit.GPatternReplacement);
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #endregion
      gAssemblyGroup.GAssemblyUnits[gAssemblyUnit.Philote] = gAssemblyUnit;
      #region TitularAssemblyUnitName Interfaces

      assemblyGroupName = "AssemblyGroupNameReplacementPattern";
      gAssemblyUnitPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex($"AssemblyUnitNameReplacementPattern"), $"{assemblyGroupName}"}
      });
      foreach (var kvp in gAssemblyGroupPatternReplacement.GDictionary) {
        gAssemblyUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }

      assemblyUnitName = $"{assemblyGroupName}";
      gAssemblyUnit = new GAssemblyUnit($"{assemblyUnitName}.Interfaces", gRelativePath: $"{assemblyGroupName}.Interfaces",
        gProjectUnit: new GProjectUnit($"{assemblyUnitName}.Interfaces",
          gPatternReplacement: gAssemblyUnitPatternReplacement), gPatternReplacement: gAssemblyUnitPatternReplacement);

      #region TitularCompilationUnitName Base Interfaces with embedded Data
      gCompilationPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
      });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gCompilationPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      var compilationUnitName = $"{assemblyUnitName}";
      gCompilationUnit = new GCompilationUnit($"{compilationUnitName}Base.Interfaces", gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gCompilationPatternReplacement);
      gNamespace = new GNamespace($"{baseNamespace}.{compilationUnitName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      gInterface = new GInterface($"I{compilationUnitName}Base");
      gCompilationUnit.GNamespaces[gNamespace.Philote].GInterfaces[gInterface.Philote] = gInterface;

      gInterface = new GInterface($"I{compilationUnitName}BaseData");
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
//GArgument arg1 = new GArgument("arg1", "int");
//GArgument arg2 = new GArgument("arg2", "string", isOut: true);
//GArgument arg3 = new GArgument("arg3", "Philote<GArgument>", isRef: true);
//Dictionary<Philote<GArgument>, GArgument> gMethodArguments =
//  new Dictionary<Philote<GArgument>, GArgument>() { { arg1.Philote, arg1 }, { arg2.Philote, arg2 }, { arg3.Philote, arg3 } };
//GMethodDeclaration gMethodDeclaration =
//  new GMethodDeclaration(gName: "ServiceData", isConstructor:true,gMethodArguments:gMethodArguments);
//GBody gBody = new GBody(statementList: new List<string>() { "A=a", "B=b" });
//var gConstructor = new GMethod(gMethodDeclaration, gBody);

//gCompilationUnits = new Dictionary<Philote<GCompilationUnit>, GCompilationUnit>();
//gCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
