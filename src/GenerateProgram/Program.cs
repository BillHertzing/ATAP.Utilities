using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using ATAP.Utilities.Philote;
//using AutoMapper.Configuration;

namespace GenerateProgram {
  class Program {
    static void Main(string[] args) {
      // Get the Artifacts directory from the host
      string ArtifactsPath = "../../../Artifacts/";
      GCompilationUnit gCompilationUnit;
      gCompilationUnit = new GCompilationUnit("TestFile", gRelativePath: ArtifactsPath, gFileSuffix: ".cs");
      GUsing gUsing;
      GUsingGroup gUsingGroup;
      gUsingGroup = new GUsingGroup("Usings For GenericHost");
      foreach (var gName in new List<string>() {
        "Microsoft.Extensions.Localization","Microsoft.Extensions.Options","Microsoft.Extensions.Configuration","Microsoft.Extensions.Logging",
        "Microsoft.Extensions.Logging.Abstractions", "Microsoft.Extensions.DependencyInjection", "Microsoft.Extensions.Hosting","Microsoft.Extensions.Hosting.Internal"}) {
        gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      gUsingGroup = new GUsingGroup("Usings For System");
      foreach (var gName in new List<string>() {
        "System","System.Collections.Generic","System.IO","System.Text","System.Threading","System.Threading.Tasks",
        "System.Diagnostics","System.Globalization","System.Linq"}) {
        gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      gUsing = new GUsing("StandaloneUsing1");
      gCompilationUnit.GUsings[gUsing.Philote] = gUsing;
      gUsing = new GUsing("StandaloneUsing2");
      gCompilationUnit.GUsings[gUsing.Philote] = gUsing;

      GNamespace gNamespace = new GNamespace("Base.ServiceName");
      gCompilationUnit.GNamespaces[gNamespace.Philote] = gNamespace;
      GClass gClass = new GClass("NameOfServiceData", "public", gImplements: new List<string> { "IDisposable" }, gDisposesOf: new List<string> { "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle" });
      GMethod gConstructor = new GMethod(new GMethodDeclaration("NameOfServiceData", isConstructor: true, gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;
      List<GProperty> gPropertys = new List<GProperty>()  {
                new GProperty("ConfigurationRoot", gAccessors:"{ get; }"),
                new GProperty("Choices", gType: "IEnumerable<string>", gAccessors:"{ get; }"),
                new GProperty("SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle", gType: "IDisposable", gAccessors:"{ get; }"),
                new GProperty("StdInHandlerState", gType: "StringBuilder", gAccessors:"{ get; }")
            };
      foreach (var o in gPropertys) {
        gClass.GPropertys[o.Philote] = o;
      }
      gNamespace.GClasss[gClass.Philote] = gClass;

      gClass = new GClass("NameOfService", "public", gImplements: new List<string> { "IDisposable" }, gDisposesOf: new List<string> { "ServiceNameData" });
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
      gConstructor = new GMethod(new GMethodDeclaration("ServiceName", isConstructor: true, gVisibility: "public"));
      gClass.GConstructors[gConstructor.Philote] = gConstructor;
      List<string> AutoProperties = new List<string>() {
        "LoggerFactory",
        "StringLocalizerFactory",
        "HostEnvironment",
        "HostConfiguration",
        "HostLifetime",
        "AppConfiguration",
        "HostApplicationLifetime"
      };
      GPropertyGroup gPropertyGroup = new GPropertyGroup("Injected AutoProperty Group for GenericHost");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var ap in AutoProperties) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, ap, gPropertyGroupId: gPropertyGroup.Philote);
      }
      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for logger");
      gClass.AddPropertyGroups(gPropertyGroup);
      gClass.AddTLoggerConstructorAutoPropertyGroup(gConstructor.Philote, gPropertyGroupId: gPropertyGroup.Philote);
      AutoProperties.Clear();
      AutoProperties.AddRange(new List<string>() { "debugLocalizer", "exceptionLocalizer", "uiLocalizer" });
      gPropertyGroup = new GPropertyGroup("Derived AutoProperty Group for Localizers");
      gClass.AddPropertyGroups(gPropertyGroup);
      string assemblyName = "ToDoAssemblyName";
      foreach (var ap in AutoProperties) {
        gClass.AddTLocalizerConstructorAutoPropertyGroup(gConstructor.Philote, ap, assemblyName, gPropertyGroupId: gPropertyGroup.Philote);
      }


      gNamespace.GClasss[gClass.Philote] = gClass;
      GInterface gInterface = new GInterface("ServiceData");
      gNamespace.GInterfaces[gInterface.Philote] = gInterface;
      var session = new System.Collections.Generic.Dictionary<string, object>();
      var compilationUnits = new Dictionary<Philote<GCompilationUnit>, GCompilationUnit>();
      compilationUnits[gCompilationUnit.Philote] = gCompilationUnit;
      session.Add("compilationUnits", gCompilationUnit);
      // session.Add gNamespace.End
      StringBuilder indent = new StringBuilder(8192);
      string indentDelta = "  ";
      string eol = Environment.NewLine;
      CancellationTokenSource cts = new CancellationTokenSource();
      CancellationToken ct = cts.Token;
      var r1TopData = new R1TopData(indent, indentDelta, eol, ct);
      StringBuilder sb = new StringBuilder();
      var r1Top = new R1Top(session, r1TopData, sb);
      var w1Top = new W1Top();
      r1Top.Render(w1Top);

      //  Invoke Editor or Compiler or IDE or Tests on the output files
      Console.WriteLine(r1Top.Sb);
      var wait = Console.ReadLine();
    }
  }


}
