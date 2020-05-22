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
using static GenerateProgram.Lookup;
using static GenerateProgram.StringConstants;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.GAssemblyUnitExtensions;
using static GenerateProgram.GCompilationUnitExtensions;
using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.GMacroExtensions;
//using AutoMapper.Configuration;

namespace GenerateProgram {

  class Program {
    static void Main(string[] args) {

      // ToDo: Get the Artifacts directory from the host
      string artifactsPath = "D:/Temp/GenerateProgramArtifacts/GenericHostHostedServices/";
      string baseNamespace = "ATAPConsole02";

      var nonReleasedPackageNames = new List<string>() {
        "Timers",
        "FilesystemWatchers",
        "ConsoleSource",
        "ConsoleSink",
        "ConsoleMonitor",
        "FileSystemToObjectGraph",
        "TopLevelBackgroundService",
      };
      var interfaces = ".Interfaces";
      var fromPatternP = "<PackageReference Include=\"";
      var fromPatternS = "\"\\s*/>";
      var toPatternP = "<ProjectReference Include=\"";
      var toPatternS = "\" />";
      List<KeyValuePair<Regex, string>> nonReleasedPackageKVPs = new List<KeyValuePair<Regex, string>>();
      foreach (var s in nonReleasedPackageNames) {
        nonReleasedPackageKVPs.Add(new KeyValuePair<Regex, string>(
          new Regex(fromPatternP + s + fromPatternS), toPatternP + artifactsPath + s + "/" + s + ".csproj" + toPatternS
          ));
        nonReleasedPackageKVPs.Add(new KeyValuePair<Regex, string>(
          new Regex(fromPatternP + s + interfaces + fromPatternS), toPatternP + artifactsPath + s + interfaces + "/" + s + interfaces + ".csproj" + toPatternS
        ));
      }
      var nonReleasedPackageReplacementDictionary = new Dictionary<Regex, string>();
      foreach (var kvp in nonReleasedPackageKVPs) {
        nonReleasedPackageReplacementDictionary.Add(kvp.Key, kvp.Value);
      }
      #region GReplacementPatternDictionary for NonReleasedPackages
      var gNonReleasedPackagesPatternReplacement = new GPatternReplacement(gName: "NonReleasedPackages",
        gDictionary: nonReleasedPackageReplacementDictionary);
      #endregion
      string subDirectoryForGeneratedFiles = "Generated";
      StringBuilder sb = new StringBuilder(0x2000);
      StringBuilder indent = new StringBuilder(64);
      string indentDelta = "  ";
      string eol = Environment.NewLine;
      CancellationTokenSource cts = new CancellationTokenSource();
      CancellationToken ct = cts.Token;
      var session = new System.Collections.Generic.Dictionary<string, object>();
      R1Top r1Top;
      W1Top w1Top;
      GAssemblyGroup gAssemblyGroup = GAssemblyGroupGHHSConstructor("Timers", subDirectoryForGeneratedFiles, baseNamespace, gPatternReplacement: gNonReleasedPackagesPatternReplacement);
      #region Declare and populate the initial rawDiGraph, which handles basic states for a GHHS
      List<string> rawDiGraph = new List<string>() {
        @"WaitingForInitialization ->BlockingOnConsoleInReadLineAsync [label = ""InitializationCompleteReceived""]",
        @"ServiceFaulted ->ShutdownStarted [label = ""CancellationTokenActivated""]",
        @"ServiceFaulted ->ShutdownStarted [label = ""StopAsyncActivated""]",
        @"ShutdownStarted->ShutDownComplete [label = ""AllShutDownStepsCompleted""]",
      };
      #endregion
      #region Select the Titular AssemblyUnit, TitularBase CompilationUnit, Namespace, Class, and Constructor
      var titularBaseClassName = $"{"Timers"}Base";
      var lookupResultsForTitularBase = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>() { gAssemblyGroup }, gClassName: titularBaseClassName);
      if (lookupResultsForTitularBase.gMethods.Count() == 0) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      #endregion
      #region StateMachine Configuration for this specific service
      rawDiGraph.AddRange(new List<string>(){
        @"BlockingOnConsoleInReadLineAsync -> ServiceFaulted [label = ""ExceptionCaught""]",
        @"BlockingOnConsoleInReadLineAsync -> ShutdownStarted [label = ""CancellationTokenActivated""]",
      });
      MStateMachineDetails(lookupResultsForTitularBase, rawDiGraph);
      #endregion
      GAssemblyGroupCommonFinalizer(gAssemblyGroup);
      GAssemblyGroupPopulateInterfaces(gAssemblyGroup);
      session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      w1Top = new W1Top(basePath: artifactsPath, force: true);
      r1Top.Render(w1Top);
      session.Clear();
      gAssemblyGroup = GAssemblyGroupGHHSConstructor("FilesystemWatchers", subDirectoryForGeneratedFiles, baseNamespace, gPatternReplacement: gNonReleasedPackagesPatternReplacement);
      GAssemblyGroupPopulateInterfaces(gAssemblyGroup);
      session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      w1Top = new W1Top(basePath: artifactsPath, force: true);
      r1Top.Render(w1Top);
      session.Clear();

      gAssemblyGroup = MConsoleSource(subDirectoryForGeneratedFiles, baseNamespace, gPatternReplacement: gNonReleasedPackagesPatternReplacement);
      session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      w1Top = new W1Top(basePath: artifactsPath, force: true);
      r1Top.Render(w1Top);
      session.Clear();
      gAssemblyGroup = MConsoleSink(subDirectoryForGeneratedFiles, baseNamespace, gPatternReplacement: gNonReleasedPackagesPatternReplacement);
      session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      w1Top = new W1Top(basePath: artifactsPath, force: true);
      r1Top.Render(w1Top);
      session.Clear();
      gAssemblyGroup = MConsoleMonitor(subDirectoryForGeneratedFiles, baseNamespace, gPatternReplacement: gNonReleasedPackagesPatternReplacement);
      session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      w1Top = new W1Top(basePath: artifactsPath, force: true);
      r1Top.Render(w1Top);
      session.Clear();
      gAssemblyGroup = MTopLevelBackgroundService(subDirectoryForGeneratedFiles, baseNamespace, gPatternReplacement: gNonReleasedPackagesPatternReplacement);
      session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      w1Top = new W1Top(basePath: artifactsPath, force: true);
      r1Top.Render(w1Top);
      session.Clear();
      gAssemblyGroup = MFileSystemToObjectGraph(subDirectoryForGeneratedFiles, baseNamespace, gPatternReplacement: gNonReleasedPackagesPatternReplacement);
      session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      w1Top = new W1Top(basePath: artifactsPath, force: true);
      r1Top.Render(w1Top);
      session.Clear();

      //  Invoke Editor or Compiler or IDE or Tests on the output files
      //Console.WriteLine(r1Top.Sb);
      //Console.WriteLine("Press any Key to exit");
      //var wait = Console.ReadLine();

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
