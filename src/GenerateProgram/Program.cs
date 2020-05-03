using System;
using System.CodeDom;
using System.Collections.Generic;
using System.Drawing.Text;
using System.Linq;
using System.Security.Permissions;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;
using static GenerateProgram.StringConstants;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static GenerateProgram.GCompilationUnitExtensions;
using static GenerateProgram.GCompilationUnitExtensions;
//using AutoMapper.Configuration;

namespace GenerateProgram {

  class Program {
    static void Main(string[] args) {

      // ToDo: Get the Artifacts directory from the host
      string ArtifactsPath = "D:/Temp/GenerateProgramArtifacts";
      string BaseNamespace = "ATAPConsole02";

      string assemblyGroupName = "NewGenericHostHostedService";
      List<string> assemblyNames = new List<string>();

      GAssemblyUnit gAssemblyUnit;
      Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit> gAssemblyUnits;
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
      List<string> AutoProperties;

      GPropertyGroupInProjectUnit gPropertyGroupInProjectUnit;
      List<String> gPropertyGroupStatements;
      GItemGroupInProjectUnit gItemGroupInProjectUnit;
      List<String> gItemGroupStatements;

      gAssemblyUnits = new Dictionary<Philote<GAssemblyUnit>, GAssemblyUnit>();

      #region TitularAssemblyUnit
      var TitularAssemblyUnitName = assemblyGroupName;
      gAssemblyUnit = new GAssemblyUnit(assemblyGroupName,gRelativePath:TitularAssemblyUnitName, gProjectUnit: new GProjectUnit(TitularAssemblyUnitName));
      #region TitularCompilationUnit With Embedded Data Class
      var TitularCompilationUnitName = assemblyGroupName;
      gCompilationUnit = new GCompilationUnit(TitularCompilationUnitName, gFileSuffix: ".cs");
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

      gNamespace = new GNamespace($"{BaseNamespace}.{TitularCompilationUnitName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;

      #region embedded Data Class
      gClass = new GClass($"{TitularCompilationUnitName}Data", "public", gImplements: new List<string> { "IDisposable" }, gDisposesOf: new List<string> { "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle" });
      gConstructor = new GMethod(new GMethodDeclaration($"{TitularCompilationUnitName}Data", isConstructor: true, gVisibility: "public"));
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
      #region TitularClass
      gClass = new GClass(TitularCompilationUnitName, "public", gImplements: new List<string> { "IDisposable" }, gDisposesOf: new List<string> { $"{TitularCompilationUnitName}Data" });
      gConstructor = new GMethod(new GMethodDeclaration(TitularCompilationUnitName, isConstructor: true, gVisibility: "public"));
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

      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for logger");
      gClass.AddPropertyGroups(gPropertyGroup);
      gClass.AddTLoggerConstructorAutoPropertyGroup(gConstructor.Philote, gPropertyGroupId: gPropertyGroup.Philote);

      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Localizers");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in new List<string>() { "debugLocalizer", "exceptionLocalizer", "uiLocalizer" }) {
        gClass.AddTLocalizerConstructorAutoPropertyGroup(gConstructor.Philote, ap, assemblyNameReplacementPattern, gPropertyGroupId: gPropertyGroup.Philote);
      }

      gMethodGroup = new GMethodGroup(gName: "Methods as promised For IHostedService");
      var specificallyGeneratedGMethodGroup = gMethodGroup.CreateStartStopAsyncMethods();
      gClass.AddMethodGroup(specificallyGeneratedGMethodGroup);

      gNamespace.GClasss[gClass.Philote] = gClass;
      #endregion
      #endregion 
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;

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

      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForLibrary();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForPackableOnBuild();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForLifecycleStage();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForBuildConfigurations();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;
      gPropertyGroupInProjectUnit = PropertyGroupInProjectUnitForVersion();
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] = gPropertyGroupInProjectUnit;

      gItemGroupInProjectUnit = ItemGroupInProjectUnitForEntireService();
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

      gCompilationUnit = gCompilationUnit.CompilationUnitStringConstants(gNamespaceName: gNamespace.GName);
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion

      gAssemblyUnits[gAssemblyUnit.Philote] = gAssemblyUnit;
      #region TitularAssemblyUnitName Interfaces
      var TitularAssemblyInterfacesUnitName = $"{TitularAssemblyUnitName}.Interfaces";
      gAssemblyUnit = new GAssemblyUnit(TitularAssemblyInterfacesUnitName, gRelativePath:TitularAssemblyInterfacesUnitName , gProjectUnit: new GProjectUnit(TitularAssemblyInterfacesUnitName));

      #region TitularCompilationUnitName Interfaces with embedded Data
      var TitularCompilationInterfacesUnitName = TitularAssemblyInterfacesUnitName;
      gNamespace = new GNamespace($"{BaseNamespace}.{TitularCompilationUnitName}");
      gCompilationUnit = new GCompilationUnit(TitularCompilationInterfacesUnitName, gFileSuffix: ".cs");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      gInterface = new GInterface($"I{TitularCompilationUnitName}Data");
      gCompilationUnit.GNamespaces[gNamespace.Philote].GInterfaces[gInterface.Philote] = gInterface;

      gInterface = new GInterface($"I{TitularCompilationUnitName}");
      gCompilationUnit.GNamespaces[gNamespace.Philote].GInterfaces[gInterface.Philote] = gInterface;

      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      #endregion
      #endregion
      gAssemblyUnits[gAssemblyUnit.Philote] = gAssemblyUnit;


      var session = new System.Collections.Generic.Dictionary<string, object>();
      //session.Add("compilationUnits", gCompilationUnit);
      session.Add("assemblyUnits", gAssemblyUnits);
      StringBuilder sb = new StringBuilder(0x2000);
      StringBuilder indent = new StringBuilder(64);
      string indentDelta = "  ";
      string eol = Environment.NewLine;
      CancellationTokenSource cts = new CancellationTokenSource();
      CancellationToken ct = cts.Token;
      var r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      var w1Top = new W1Top(basePath: ArtifactsPath,force:true);
      r1Top.Render(w1Top);

      //  Invoke Editor or Compiler or IDE or Tests on the output files
      Console.WriteLine(r1Top.Sb);
      Console.WriteLine("Press any Key to exit");
      var wait = Console.ReadLine();
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
