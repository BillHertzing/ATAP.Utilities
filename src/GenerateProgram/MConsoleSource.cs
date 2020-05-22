using System;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.Philote;

using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.Lookup;
//using AutoMapper.Configuration;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblyGroup MConsoleSource(
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;

      var gAssemblyGroupName = "ConsoleSource";
      var gAssemblyGroup = GAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, _gPatternReplacement);
      #region Declare and populate the initial rawDiGraph, which handles basic states for a GHHS
      List<string> rawDiGraph = new List<string>() {
        @"WaitingForInitialization ->BlockingOnConsoleInReadLineAsync [label = ""InitializationCompleteReceived""]",
        @"ServiceFaulted ->ShutdownStarted [label = ""CancellationTokenActivated""]",
        @"ServiceFaulted ->ShutdownStarted [label = ""StopAsyncActivated""]",
        @"ShutdownStarted->ShutDownComplete [label = ""AllShutDownStepsCompleted""]",
      };
      #endregion
      #region Select the Titular AssemblyUnit, TitularBase CompilationUnit, Namespace, Class, and Constructor
      var titularBaseClassName = $"{gAssemblyGroupName}Base";
      var lookupResultsForTitularBase = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>() {gAssemblyGroup},  gClassName:titularBaseClassName);
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

      #region Add the UsingGroup for this service
      var gUsingGroup = new GUsingGroup($"Usings specific to {lookupResultsForTitularBase.gCompilationUnits.First().GName}");
      foreach (var gName in new List<string>() {
        "System.Reactive.Linq",
        "System.Reactive.Concurrency",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      lookupResultsForTitularBase.gCompilationUnits.First().GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      #endregion
      #region Add the MethodGroup for this service
      var gMethodGroup =
        new GMethodGroup(gName: $"MethodGroup specific to {lookupResultsForTitularBase.gCompilationUnits.First().GName}");
      GMethod gMethod = CreateConsoleReadLineAsyncAsObservableMethod();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      lookupResultsForTitularBase.gClasss.First().AddMethodGroup(gMethodGroup);
      #endregion

      #region References to be added to the Titular ProjectUnit
      #region References common to both Titular and Base
      foreach (var o in new List<GItemGroupInProjectUnit>() {
          ReactiveUtilitiesReferencesItemGroupInProjectUnit(),
        }
      ) {
        lookupResultsForTitularBase.gAssemblyUnits.First().GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o);
      }
      #endregion
      #endregion

      /*******************************************************************************/
      #region Populate the Interface Assembly
      #region Populate the Interfaces
      GAssemblyGroupPopulateInterfaces(gAssemblyGroup);
      #endregion
      #region Add Package references unique to this service used by the Interface Assembly
      var titularInterfaceAssemblyName = $"{gAssemblyGroup.GName}.Interfaces";
      var lookupResultsForProjectAssembly = LookupProjectUnits(new List<GAssemblyGroup>() {gAssemblyGroup}, gAssemblyUnitName: titularInterfaceAssemblyName);
      foreach (var o in new List<GItemGroupInProjectUnit>() {
          ReactiveUtilitiesReferencesItemGroupInProjectUnit(),
        }
      ) {
        lookupResultsForProjectAssembly.gProjectUnits.First().GItemGroupInProjectUnits.Add(o.Philote, o);
      }
      #endregion
      #endregion
      return gAssemblyGroup;
      /*******************************************************************************/
      /*******************************************************************************/

      static GMethod CreateConsoleReadLineAsyncAsObservableMethod(string gAccessModifier = "") {
        var gMethodArgumentList = new List<GArgument>() {
        // None
        };
        var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
        foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }
        return new GMethod(
        new GMethodDeclaration(gName: "ConsoleReadLineAsyncAsObservable", gType: "IObservable<string>",
          gVisibility: "public", gAccessModifier: gAccessModifier, isConstructor: false,
        gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
        new List<string>() {
      @"     return",
      @"         Observable",
      @"             .FromAsync(() => Console.In.ReadLineAsync()) // This is actually a BLOCKING operation, see ?? for workaround",
      @"             .Repeat()",
      @"             .Publish()",
      @"             .RefCount()",
      @"             .SubscribeOn(Scheduler.Default);",
        }),
        new GComment(new List<string>() {
      "// Convert the Console.In.ReadLineAsync into an IObservable in this service",
        }));
      }
    }
  }
}
