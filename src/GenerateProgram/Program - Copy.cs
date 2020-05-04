using System;
using System.CodeDom;
using System.Collections.Generic;
using System.Drawing.Text;
using System.Linq;
using System.Security.Permissions;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using ATAP.Utilities.Philote;
using static GenerateProgram.StringConstants;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static GenerateProgram.GCompilationUnitExtensions;
using static GenerateProgram.GCompilationUnitExtensions;
//using AutoMapper.Configuration;

namespace GenerateProgram {

  static partial class Extensions  {
    static GAssemblyGroup GAssemblyGroupGHHSConstructor(string assemblyGroupName=default){
      GAssemblyUnit gAssemblyUnit;

      GPatternReplacement gPatternReplacement;
      GResourceUnit gResourceUnit;
      Dictionary<Philote<GResourceUnit>, GResourceUnit> gResourceUnits;
      GResourceItem gResourceItem;
      Dictionary<Philote<GResourceItem>, GResourceItem> gResourceItems;
      GCompilationUnit gCompilationUnit;
      Dictionary<Philote<GCompilationUnit>, GCompilationUnit> gCompilationUnits;
      GUsing gUsing;
      Dictionary<Philote<GUsing>, GUsing> gUsings;
      GUsingGroup gUsingGroup;
      Dictionary<Philote<GUsingGroup>, GUsingGroup> gUsingGroups;
      GNamespace gNamespace;
      Dictionary<Philote<GNamespace>, GNamespace> gNamespaces;
      GClass gClass;
      Dictionary<Philote<GClass>, GClass> gClasss;
      GProperty gProperty;
      Dictionary<Philote<GProperty>, GProperty> gPropertys;
      GPropertyGroup gPropertyGroup;
      Dictionary<Philote<GPropertyGroup>, GPropertyGroup> gPropertyGroups;
      GMethod gConstructor;
      GMethod gMethod;
      GMethodGroup gMethodGroup;
      GInterface gInterface;

      GPropertyGroupInProjectUnit gPropertyGroupInProjectUnit;
      GItemGroupInProjectUnit gItemGroupInProjectUnit;

      GPatternReplacement gAssemblyGroupPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("AssemblyGroupNameReplacementPattern"), assemblyGroupName},
        {new Regex("SolutionReferencedProjectsBasePathReplacementPattern"), @"C:/Dropbox/whertzing/GitHub/ATAP.Utilities/"}
      });
      gAssemblyGroup = new GAssemblyGroup(assemblyGroupName,gPatternReplacement:gAssemblyGroupPatternReplacement);

      #region TitularAssemblyUnit
      var TitularAssemblyUnitName = assemblyGroupName;
      gPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("AssemblyUnitNameReplacementPattern"), TitularAssemblyUnitName}
      });
      foreach (var kvp in gAssemblyGroupPatternReplacement.GDictionary) {
        gPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }

      #region TitularCompilationUnit With Embedded Data Class
      var TitularCompilationUnitName = assemblyGroupName;
      gAssemblyUnit = new GAssemblyUnit(TitularAssemblyUnitName, gRelativePath: TitularAssemblyUnitName,
        gProjectUnit: new GProjectUnit(TitularAssemblyUnitName, gPatternReplacement:gPatternReplacement),gPatternReplacement:gPatternReplacement);

      gCompilationUnit = new GCompilationUnit($"{TitularCompilationUnitName}Base", gFileSuffix: ".cs",gRelativePath:relativePathForGeneratedFiles, gPatternReplacement:gAssemblyUnit.GPatternReplacement);

      gUsingGroup = new GUsingGroup().UsingsForMicrosoftGenericHost();
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;

      gUsingGroup = new GUsingGroup("Usings For System");
      foreach (var gName in new List<string>() {
        "System","System.Collections.Generic","System.IO","System.Text","System.Threading","System.Threading.Tasks",
        "System.Diagnostics","System.Globalization","System.Linq"}) {
        gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;

      gNamespace = new GNamespace($"{baseNamespace}.{TitularCompilationUnitName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;

      #region embedded Data Class generated Base
      gClass = new GClass($"{TitularCompilationUnitName}BaseData", "public", gImplements: new List<string> { "IDisposable" }, gDisposesOf: new List<string> { "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle" });
      gConstructor = new GMethod(new GMethodDeclaration($"{TitularCompilationUnitName}BaseData", isConstructor: true, gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;

      List<GProperty> gPropertyList = new List<GProperty>(){
        new GProperty("ConfigurationRoot", gAccessors:"{ get; }"),
        new GProperty("Choices", gType: "IEnumerable<string>", gAccessors:"{ get; }"),
        new GProperty("SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle", gType: "IDisposable", gAccessors:"{ get; }"),
        new GProperty("StdInHandlerState", gType: "StringBuilder", gAccessors:"{ get; }")
      };
      gPropertyList.ForEach(gProperty => gClass.GPropertys[gProperty.Philote] = gProperty);
      gNamespace.GClasss[gClass.Philote] = gClass;
      #endregion
      #region TitularClass generated Base
      gClass = new GClass($"{TitularCompilationUnitName}Base", "public",  gImplements: new List<string> { "IHostedService", "IDisposable" }, gDisposesOf: new List<string> { $"{TitularCompilationUnitName}Data" });
      gConstructor = new GMethod(new GMethodDeclaration($"{TitularCompilationUnitName}Base", isConstructor: true, gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;

      gPropertyGroup = new GPropertyGroup("Injected AutoProperty Group for GenericHost");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in new List<string>() {"LoggerFactory", "StringLocalizerFactory", "HostEnvironment", "HostLifetime", "HostApplicationLifetime"
      }) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, ap, gPropertyGroupId: gPropertyGroup.Philote);
      }
      foreach (var ap in new List<string>() { "HostConfiguration", "AppConfiguration" }) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, ap, gType: "IConfiguration", gPropertyGroupId: gPropertyGroup.Philote);
      }

      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Logger");
      gClass.AddPropertyGroups(gPropertyGroup);
      gClass.AddTLoggerConstructorAutoPropertyGroup(gConstructor.Philote, gPropertyGroupId: gPropertyGroup.Philote);

      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Localizers");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in new List<string>() { "DebugLocalizer", "ExceptionLocalizer", "UiLocalizer" }) {
        gClass.AddTLocalizerConstructorAutoPropertyGroup(gConstructor.Philote, ap, assemblyUnitName, gPropertyGroupId: gPropertyGroup.Philote);
      }

      gClass.AddMethodGroup(new GMethodGroup(gName: "Methods as promised For IHostedService").CreateStartStopAsyncMethods());

      gMethodGroup = new GMethodGroup(gName: "Methods as promised For IBackgroundService");
      gMethod = new GMethod().CreateExecuteAsyncMethod();
      gMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gClass.AddMethodGroup(gMethodGroup);

      gMethodGroup = new GMethodGroup(gName: "EventHandler Methods registered with HostApplicationLifetime events").CreateHostApplicationLifetimeEventHandlerMethods();
      gClass.AddMethodGroup(gMethodGroup);

      gNamespace.GClasss[gClass.Philote] = gClass;
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;

      #region non-Base code
      #region non-base compilationUnit declaration
      gCompilationUnit = new GCompilationUnit($"{TitularCompilationUnitName}", gFileSuffix: ".cs",  gPatternReplacement:gAssemblyUnit.GPatternReplacement);
      gUsingGroup = new GUsingGroup("Usings For System");
      foreach (var gName in new List<string>() {
        "System","System.Collections.Generic","System.IO","System.Text","System.Threading","System.Threading.Tasks",
        "System.Diagnostics","System.Globalization","System.Linq"}) {
        gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      gNamespace = new GNamespace($"{baseNamespace}.{TitularCompilationUnitName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      #endregion
      #region non-base embedded Data class
      gClass = new GClass($"{TitularCompilationUnitName}Data", "public", gAccessModifier: "partial", gInheritance:$"{TitularCompilationUnitName}BaseData", gImplements: new List<string> { "IDisposable" }, gDisposesOf: new List<string> { "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle" });
      gConstructor = new GMethod(new GMethodDeclaration($"{TitularCompilationUnitName}Data", isConstructor: true, gBase:"ToDo:base arguments", gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;
      gNamespace.GClasss[gClass.Philote] = gClass;
      #endregion
      #region non-base TitularClass
      gClass = new GClass(TitularCompilationUnitName, "public",gAccessModifier: "partial",  gInheritance: $"{TitularCompilationUnitName}Base", gImplements: new List<string> { "IHostedService", "IDisposable" }, gDisposesOf: new List<string> { $"{TitularCompilationUnitName}Data", $"{TitularCompilationUnitName}Base" });
      gConstructor = new GMethod(new GMethodDeclaration(TitularCompilationUnitName, isConstructor: true, gVisibility: "public",gBase:"ToDo:base arguments"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;
      gNamespace.GClasss[gClass.Philote] = gClass;
      #endregion
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion 

      #endregion
      #endregion 

      gResourceItem = new GResourceItem(gName: "ExceptionMessage1", gValue: "text for exception {0}", gComment: "{0} is the exception something?");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem>();
      gResourceItems[gResourceItem.Philote] = gResourceItem;
      gResourceUnit = new GResourceUnit("ExceptionMessages", gRelativePath: "Resources", gResourceItems: gResourceItems);
      gAssemblyUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      gAssemblyUnit.GProjectUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;

      gResourceItem = new GResourceItem(gName: "Enter Selection>", gValue: "Enter Selection>", gComment: "Enter Selection prompt for Console UI");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem>();
      gResourceItems[gResourceItem.Philote] = gResourceItem;
      gResourceUnit = new GResourceUnit("UIMessages", gRelativePath: "Resources", gResourceItems: gResourceItems);
      gAssemblyUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      gAssemblyUnit.GProjectUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;

      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForProjectUnitIsLibrary();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForPackableOnBuild();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForLifecycleStage();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForBuildConfigurations();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForVersion();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;

      gItemGroupInProjectUnit = ProjectReferenceItemGroupInProjectUnitForLoggingUtilities();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ProjectReferenceItemGroupInProjectUnitForConsoleServices();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ProjectReferenceItemGroupInProjectUnitForPersistenceUtilities();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ProjectReferenceItemGroupInProjectUnitForGenericHostUtilities();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ProjectReferenceItemGroupInProjectUnitForTimersService();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;

      gItemGroupInProjectUnit = ItemGroupInProjectUnitForQuickGraphPackageReferences();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ItemGroupInProjectUnitForQuickGraphDependentPackageReferences();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ItemGroupInProjectUnitForReactiveExtensionsPackageReferences();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ItemGroupInProjectUnitForServiceStackSerializationPackageReferences();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ItemGroupInProjectUnitForServiceStackORMLitePackageReferences();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ItemGroupInProjectUnitForNetCoreGenericHostAndWebServerHostPackageReferences();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ItemGroupInProjectUnitForSerilogLoggingProviderPackageReferences();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ItemGroupInProjectUnitForSerilogAndSeqMELLoggingProviderPackageReferences();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;
      gItemGroupInProjectUnit = ItemGroupInProjectUnitForILWeavingUsingFodyPackageReferences();
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits[gItemGroupInProjectUnit.Philote] = gItemGroupInProjectUnit;

      #region region StringConstantsBase
      gCompilationUnit = CompilationUnitStringConstantsConstructor(gNamespaceName: gNamespace.GName, gRelativePath:relativePathForGeneratedFiles, gPatternReplacement:gAssemblyUnit.GPatternReplacement);
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #endregion
      gAssemblyGroup.GAssemblyUnits[gAssemblyUnit.Philote] = gAssemblyUnit;

      #region TitularAssemblyUnitName Interfaces
      var TitularAssemblyInterfacesUnitName = $"{TitularAssemblyUnitName}.Interfaces";
      var TitularAssemblyInterfacesBaseUnitName = $"{TitularAssemblyUnitName}Base.Interfaces";
      gPatternReplacement = new GPatternReplacement(gDictionary: new Dictionary<Regex, string>() {
        {new Regex("AssemblyUnitNameReplacementPattern"), TitularAssemblyInterfacesUnitName}
      });
      foreach (var kvp in gAssemblyGroupPatternReplacement.GDictionary) {
        gPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      gAssemblyUnit = new GAssemblyUnit(TitularAssemblyInterfacesUnitName, gRelativePath: TitularAssemblyInterfacesUnitName,
        gProjectUnit: new GProjectUnit(TitularAssemblyInterfacesUnitName, gPatternReplacement:gAssemblyUnit.GPatternReplacement),gPatternReplacement:gPatternReplacement);

      #region TitularCompilationUnitName Base Interfaces with embedded Data
      var TitularCompilationInterfacesUnitName = TitularAssemblyInterfacesUnitName;
      var TitularCompilationInterfacesBaseUnitName = TitularAssemblyInterfacesBaseUnitName;
      gCompilationUnit = new GCompilationUnit($"{TitularCompilationInterfacesBaseUnitName}", gFileSuffix: ".cs", gRelativePath:relativePathForGeneratedFiles, gPatternReplacement:gAssemblyUnit.GPatternReplacement);
      gNamespace = new GNamespace($"{baseNamespace}.{TitularCompilationUnitName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      gInterface = new GInterface($"I{TitularCompilationUnitName}BaseData");
      gCompilationUnit.GNamespaces[gNamespace.Philote].GInterfaces[gInterface.Philote] = gInterface;

      gInterface = new GInterface($"I{TitularCompilationUnitName}Base");
      gCompilationUnit.GNamespaces[gNamespace.Philote].GInterfaces[gInterface.Philote] = gInterface;
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #endregion
      #region ProjectUnit
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForProjectUnitIsLibrary();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForPackableOnBuild();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForLifecycleStage();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForBuildConfigurations();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForVersion();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      #endregion

      gAssemblyGroup.GAssemblyUnits[gAssemblyUnit.Philote] = gAssemblyUnit;


      
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
