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
    public static GAssemblyGroup MConsoleSinkGHS(
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;

      var gAssemblyGroupName = "ConsoleSinkGHS";
      var gAssemblyGroup = MAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, _gPatternReplacement);
      #region Select the Titular AssemblyUnit, Titular StateMachineDiGraph, TitularBase CompilationUnit, Namespace, Class, and Constructor
      var titularBaseClassName = $"{gAssemblyGroupName}Base";
      var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(
        new List<GAssemblyGroup>() {gAssemblyGroup},
        gClassName: titularBaseClassName);
      if (titularAssemblyUnitLookupPrimaryConstructorResults.gMethods.Count() == 0) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      #endregion
      #region Initial StateMachine Configuration for this specific service
      titularAssemblyUnitLookupPrimaryConstructorResults.gMethods.First().GStateConfigurations.AddRange(
        new List<GStateConfiguration>() {
          new GStateConfiguration(
            gStateTransitions: new List<string>() {
              @"WaitingForInitialization -> WaitingForRequestToWriteSomething [label = ""InitializationCompleteReceived""]",
              @"WaitingForRequestToWriteSomething -> WaitingForWriteToComplete [label = ""WriteStarted""]",
              @"WaitingForWriteToComplete -> WaitingForRequestToWriteSomething [label = ""WriteFinished""]",
              @"WaitingForWriteToComplete -> WaitingForRequestToWriteSomething [label = ""CancellationTokenActivated""]",
              @"WaitingForRequestToWriteSomething -> ServiceFaulted [label = ""ExceptionCaught""]",
              @"WaitingForWriteToComplete ->ServiceFaulted [label = ""ExceptionCaught""]",
              @"WaitingForRequestToWriteSomething ->ShutdownStarted [label = ""CancellationTokenActivated""]",
              @"WaitingForRequestToWriteSomething ->ShutdownStarted [label = ""StopAsyncActivated""]",
              @"WaitingForWriteToComplete ->ShutdownStarted [label = ""StopAsyncActivated""]",
            },
            gStateConfigurationFluentChains: new List<string>() {
              // None
            }
          )
        }.AsEnumerable());
      #endregion

      #region Add the UsingGroup for this service
      var gUsingGroup =
        new GUsingGroup(
          $"Usings specific to {titularAssemblyUnitLookupPrimaryConstructorResults.gCompilationUnits.First().GName}");
      foreach (var gName in new List<string>() {
        // none
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      titularAssemblyUnitLookupPrimaryConstructorResults.gCompilationUnits.First().GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Add the MethodGroup for this service
      var gMethodGroup =
        new GMethodGroup(
          gName:
          $"MethodGroup specific to {titularAssemblyUnitLookupPrimaryConstructorResults.gCompilationUnits.First().GName}");
      GMethod gMethod;
      gMethod = MCreateWriteMethodInConsoleSink();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      titularAssemblyUnitLookupPrimaryConstructorResults.gClasss.First().AddMethodGroup(gMethodGroup);
      #endregion

      #region References to be added to the Titular ProjectUnit for this service
      #region References common to both Titular and Base for this service
      foreach (var o in new List<GItemGroupInProjectUnit>() {
          //None
        }
      ) {
        titularAssemblyUnitLookupPrimaryConstructorResults.gAssemblyUnits.First().GProjectUnit.GItemGroupInProjectUnits
          .Add(o.Philote, o);
      }
      #endregion
      #region References unique to Base for this service
      foreach (var o in new List<GItemGroupInProjectUnit>() {
          // None
        }
      ) {
        titularAssemblyUnitLookupPrimaryConstructorResults.gAssemblyUnits.First().GProjectUnit.GItemGroupInProjectUnits
          .Add(o.Philote, o);
      }
      #endregion
      #endregion

      /*******************************************************************************/
      #region Update the Interface Assembly for this service
      var titularBaseInterfaceName = $"I{gAssemblyGroupName}Base";
      var titularInterfaceName = $"I{gAssemblyGroupName}";
      #region Select the Titular Interfaces AssemblyUnit, Titular Interface Base CompilationUnit, Namespace, and Interface
      var lookupTitularBaseInterfaceResults = LookupInterfaces(
        new List<GAssemblyGroup>() {gAssemblyGroup},
        gInterfaceName: titularBaseInterfaceName);
      if (lookupTitularBaseInterfaceResults.gInterfaces.Count() == 0) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      #endregion
      #region Select the Titular Interfaces AssemblyUnit, Titular Interface Base CompilationUnit, Namespace, and Interface
      var lookupTitularInterfaceResults = LookupInterfaces(
        new List<GAssemblyGroup>() {gAssemblyGroup},
        gInterfaceName: titularInterfaceName);
      if (lookupTitularInterfaceResults.gInterfaces.Count() == 0) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      #endregion
      #region Using groups for the Titular Interface and Titular Base Interface for this service
      #region Using groups for the Titular Interface for this service
      gUsingGroup =
        new GUsingGroup($"Usings specific to {lookupTitularInterfaceResults.gCompilationUnits.First().GName}");
      foreach (var gName in new List<string>() {
        //None
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      lookupTitularInterfaceResults.gCompilationUnits.First().GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Using groups for the Titular Base Interface for this service
      gUsingGroup =
        new GUsingGroup($"Usings specific to {lookupTitularBaseInterfaceResults.gCompilationUnits.First().GName}");
      foreach (var gName in new List<string>() {
        //None
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      lookupTitularBaseInterfaceResults.gCompilationUnits.First().GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #endregion

      var titularInterfaceAssemblyName = $"{gAssemblyGroup.GName}.Interfaces";
      var lookupResultsForProjectAssembly = LookupProjectUnits(new List<GAssemblyGroup>() {gAssemblyGroup},
        gAssemblyUnitName: titularInterfaceAssemblyName);
      #region ReferenceItemGroups for the ProjectUnit that are unique to this service to be added to the Titular Interfaces ProjectUnit
      foreach (var o in new List<GItemGroupInProjectUnit>() {
         // None
        }
      ) {
        lookupResultsForProjectAssembly.gProjectUnits.First().GItemGroupInProjectUnits.Add(o.Philote, o);
      }
      #endregion
      #endregion
      #region Finalize the GHHS
      GAssemblyGroupGHHSFinalizer(gAssemblyGroup);
      #endregion
      return gAssemblyGroup;
    }
    /*******************************************************************************/
    /*******************************************************************************/
    //static GMethod MCreateWriteAsyncMethodInConsoleSink(string gAccessModifier = "") {
    //  var gMethodArgumentList = new List<GArgument>() {
    //    new GArgument("mesg","string"),
    //    new GArgument("ct","CancellationToken?")
    //  };
    //  var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
    //  foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }
    //  return new GMethod(
    //  new GMethodDeclaration(gName: "WriteAsync", gType: "Task",
    //    gVisibility: "public", gAccessModifier: gAccessModifier + " async", isConstructor: false,
    //  gArguments: gMethodArguments),
    //  gBody: new GBody(gStatements:
    //  new List<string>() {
    //"StateMachine.Fire(Trigger.WriteAsyncStarted);",
    //"ct?.ThrowIfCancellationRequested();",
    //"await Console.WriteAsync(mesg);",
    //"StateMachine.Fire(Trigger.WriteAsyncFinished);",
    //"return Task.CompletedTask;"
    //  }),
    //  new GComment(new List<string>() {
    //"// Used to asynchronously write a string to the WriteAsync method of the Console instance"
    //  }));
    //}
    static GMethod MCreateWriteMethodInConsoleSink(string gAccessModifier = "") {
      var gMethodArgumentList = new List<GArgument>() {
        new GArgument("mesg", "string"), new GArgument("ct", "CancellationToken?")
      };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in gMethodArgumentList) {
        gMethodArguments.Add(o.Philote, o);
      }
      return new GMethod(
        new GMethodDeclaration(gName: "Write", gType: "void",
          gVisibility: "public", gAccessModifier: gAccessModifier, isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            "StateMachine.Fire(Trigger.WriteStarted);",
            "ct?.ThrowIfCancellationRequested();",
            "Console.Write(mesg);",
            "StateMachine.Fire(Trigger.WriteFinished);",
          }),
        new GComment(new List<string>() {"// Used to write a string to the Console instance"}));
    }
  }
}
