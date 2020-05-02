using System;
using System.Collections.Generic;
using System.Drawing.Text;
using System.Linq;
using System.Security.Permissions;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;
using static GenerateProgram.GUsingGroupExtensions;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.GCompilationUnitExtensions;
//using AutoMapper.Configuration;

namespace GenerateProgram {

  class Program {
    static void Main(string[] args) {
      // ToDo: Get the Artifacts directory from the host
      string ArtifactsPath = "D:/Temp/GenerateProgramArtifacts";
      string BaseNamespace = "ATAPConsole02";
      string NameOfService = "ToDoNameOfService";

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
      Dictionary<Philote<GPropertyGroup>, GPropertyGroup>  gPropertyGroups;
      GMethod gConstructor;
      GMethod gMethod;
      GInterface gInterface;
      List<string> AutoProperties;

      GPropertyGroupInProjectUnit gPropertyGroupInProjectUnit;
      List<String> gPropertyGroupStatements;
      GItemGroupInProjectUnit gItemGroupInProjectUnit;
      List<String> gItemGroupStatements;

      string assemblyName;

      gCompilationUnit = new GCompilationUnit("TestFile",  gFileSuffix: ".cs");
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

      gNamespace = new GNamespace($"{BaseNamespace}.{NameOfService}" );
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;

      gClass = new GClass("ToDoNameOfServiceData", "public", gImplements: new List<string> { "IDisposable" }, gDisposesOf: new List<string> { "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle" });
      gConstructor = new GMethod(new GMethodDeclaration("ToDoNameOfServiceData", isConstructor: true, gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;

      List<GProperty> gPropertyList = new List<GProperty>(){
        new GProperty("ConfigurationRoot", gAccessors:"{ get; }"),
        new GProperty("Choices", gType: "IEnumerable<string>", gAccessors:"{ get; }"),
        new GProperty("SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle", gType: "IDisposable", gAccessors:"{ get; }"),
        new GProperty("StdInHandlerState", gType: "StringBuilder", gAccessors:"{ get; }")
      };
      gPropertyList.ForEach(gProperty=>gClass.GPropertys[gProperty.Philote]=gProperty);

      gNamespace.GClasss[gClass.Philote] = gClass;

      gClass = new GClass("ToDoNameOfService", "public", gImplements: new List<string> { "IDisposable" }, gDisposesOf: new List<string> { "ToDoNameOfServiceData" });
      gConstructor = new GMethod(new GMethodDeclaration("ToDoNameOfService", isConstructor: true, gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;

      AutoProperties = new List<string>() {
        "LoggerFactory",
        "StringLocalizerFactory",
        "HostEnvironment",
        "HostLifetime",
        "HostApplicationLifetime"
      };
      gPropertyGroup = new GPropertyGroup("Injected AutoProperty Group for GenericHost");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in AutoProperties) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, ap, gPropertyGroupId: gPropertyGroup.Philote);
      }
      AutoProperties.Clear();
      AutoProperties.AddRange(new List<string>(){"HostConfiguration","AppConfiguration"});
      foreach (var ap in AutoProperties) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, ap, gType: "IConfiguration", gPropertyGroupId: gPropertyGroup.Philote);
      }

      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for logger");
      gClass.AddPropertyGroups(gPropertyGroup);
      gClass.AddTLoggerConstructorAutoPropertyGroup(gConstructor.Philote, gPropertyGroupId: gPropertyGroup.Philote);

      AutoProperties.Clear();
      AutoProperties.AddRange(new List<string>() { "debugLocalizer", "exceptionLocalizer", "uiLocalizer" });
      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Localizers");
      gClass.AddPropertyGroups(gPropertyGroup);

      assemblyName = "AssemblyNameReplacementPattern";
      foreach (var ap in AutoProperties) {
        gClass.AddTLocalizerConstructorAutoPropertyGroup(gConstructor.Philote, ap, assemblyName, gPropertyGroupId: gPropertyGroup.Philote);
      }

      gNamespace.GClasss[gClass.Philote] = gClass;

      gAssemblyUnit = new GAssemblyUnit(NameOfService,gProjectUnit:new GProjectUnit(NameOfService));
      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;

      gCompilationUnit = new GCompilationUnit("TestFile.Interfaces", gFileSuffix: ".cs");
      gNamespace = new GNamespace($"{BaseNamespace}.{NameOfService}" );
      
      gInterface = new GInterface($"I{NameOfService}Data");
      gNamespace.GInterfaces[gInterface.Philote] = gInterface;

      gInterface = new GInterface($"I{NameOfService}");
      gNamespace.GInterfaces[gInterface.Philote] = gInterface;

      gAssemblyUnit.GCompilationUnits[gCompilationUnit.Philote] = gCompilationUnit;

      gResourceItem = new GResourceItem(gName:"ExceptionMessage1",gValue:"textfor exception {0}", gComment:"{0} is the exception something?");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem>();
      gResourceItems[gResourceItem.Philote] = gResourceItem;
      gResourceUnit = new GResourceUnit("ExceptionMessages",gRelativePath:"Resources");
      gAssemblyUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      gAssemblyUnit.GProjectUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;

      gResourceItem = new GResourceItem(gName:"Enter Selection>",gValue:"Enter Selection>", gComment:"Enter Selection prompt for Console UI");
      gResourceItems = new Dictionary<Philote<GResourceItem>, GResourceItem>();
      gResourceItems[gResourceItem.Philote] = gResourceItem;
      gResourceUnit = new GResourceUnit("UIMessages",gRelativePath:"Resources");
      gAssemblyUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;
      gAssemblyUnit.GProjectUnit.GResourceUnits[gResourceUnit.Philote] = gResourceUnit;

      gPropertyGroupStatements = new List<string>();
      gPropertyGroupInProjectUnit = new GPropertyGroupInProjectUnit("PackableProductionV1.0.0Library","what kind of an assembly", gPropertyGroupStatements);
      gPropertyGroupInProjectUnit.GPropertyGroupStatements.AddRange(new List<string>() {
        "<OutputType>Library</OutputType>",
        "<GeneratePackageOnBuild>true</GeneratePackageOnBuild>",
        "<IsPackable>true</IsPackable>",
        "<!-- Assembly, File, and Package Information for this assembly-->",
        "<!-- Build and revision are created based on date-->",
        "<MajorVersion>1</MajorVersion>",
        "<MinorVersion>0</MinorVersion>",
        "<PatchVersion>0</PatchVersion>",
        "<!-- Current Lifecycle stage for this assembly-->",
        "<PackageLifeCycleStage>Production</PackageLifeCycleStage>",
        "<!-- NuGet Package Label for the Nuget Package if the LifecycleStage is not Production-->",
        "<!-- However, if the LifecycleStage is Production, the NuGet Package Label is ignored, but MSBuild expects a non-null value  -->",
        "<PackageLabel>NA</PackageLabel>",
        "<Configurations>Debug;Release;ReleaseWithTrace</Configurations>",
      });
      gAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits[gPropertyGroupInProjectUnit.Philote] =
        gPropertyGroupInProjectUnit;


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

      var session = new System.Collections.Generic.Dictionary<string, object>();
      //session.Add("compilationUnits", gCompilationUnit);
      session.Add("assemblyUnit", gAssemblyUnit);
      // session.Add gNames pace.End
      StringBuilder sb = new StringBuilder(0x2000);
      StringBuilder indent = new StringBuilder(64);
      string indentDelta = "  ";
      string eol = Environment.NewLine;
      CancellationTokenSource cts = new CancellationTokenSource();
      CancellationToken ct = cts.Token;
      var r1Top = new R1Top(session,sb,indent,indentDelta,eol,ct);
      var w1Top = new W1Top(basePath:ArtifactsPath);
      r1Top.Render(w1Top);

      //  Invoke Editor or Compiler or IDE or Tests on the output files
      Console.WriteLine(r1Top.Sb);
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
