using System;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.Philote;
using static ATAP.Utilities.GenerateProgram.GAssemblyGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GItemGroupInProjectUnitExtensions;
using static ATAP.Utilities.GenerateProgram.Lookup;

//using AutoMapper.Configuration;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GMacroExtensions {
    public static IGAssemblyGroup MConsoleMonitorGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true) {
      return MConsoleMonitorGHS(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, hasInterfaces,
        new GPatternReplacement());
    }
    public static IGAssemblyGroup MConsoleMonitorGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true,
      IGPatternReplacement gPatternReplacement = default) {
      IGPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      var mCreateAssemblyGroupResult = MAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, hasInterfaces, _gPatternReplacement);
      #region Initial StateMachine Configuration
      mCreateAssemblyGroupResult.GPrimaryConstructorBase.GStateConfiguration.GDOTGraphStatements.Add(
    @"
          WaitingForInitialization ->BlockingOnConsoleInReadLineAsync [label = ""InitializationCompleteReceived""]
          WaitingForRequestToWriteSomething -> WaitingForWriteToComplete [label = ""WriteStarted""]
          WaitingForWriteToComplete -> WaitingForRequestToWriteSomething [label = ""WriteFinished""]
          WaitingForWriteToComplete -> WaitingForRequestToWriteSomething [label = ""CancellationTokenActivated""]
          WaitingForRequestToWriteSomething -> ServiceFaulted [label = ""ExceptionCaught""]
          WaitingForWriteToComplete ->ServiceFaulted [label = ""ExceptionCaught""]
          WaitingForRequestToWriteSomething ->ShutdownStarted [label = ""CancellationTokenActivated""]
          WaitingForRequestToWriteSomething ->ShutdownStarted [label = ""StopAsyncActivated""]
          WaitingForWriteToComplete ->ShutdownStarted [label = ""StopAsyncActivated""]
        "
      );
      #endregion
      #region Add UsingGroups to the Titular Derived and Titular Base CompilationUnits
      #region Add UsingGroups common to both the Titular Derived and Titular Base CompilationUnits
      var gUsingGroup =
        new GUsingGroup(
          $"UsingGroup common to both  {mCreateAssemblyGroupResult.GTitularDerivedCompilationUnit.GName} and {mCreateAssemblyGroupResult.GTitularBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {
        "ATAP.Utilities.GenericHostServices.ConsoleSourceGHS", "ATAP.Utilities.GenericHostServices.ConsoleSinkGHS",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.GTitularDerivedCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      mCreateAssemblyGroupResult.GTitularBaseCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Add UsingGroups specific to the Titular Base CompilationUnit
      gUsingGroup =
        new GUsingGroup(
          $"UsingGroup specific to {mCreateAssemblyGroupResult.GTitularBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {
        "System.Reactive.Linq",
        "System.Reactive.Concurrency",
        $"{baseNamespaceName}ConsoleSinkGHS",
        $"{baseNamespaceName}ConsoleSourceGHS"
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.GTitularBaseCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #endregion
      #region Injected PropertyGroup For ConsoleSinkAndConsoleSource
      var gPropertyGroup = new GPropertyGroup("Injected Property for ConsoleSinkGHS and ConsoleSourceGHS");
      mCreateAssemblyGroupResult.GClassBase.AddPropertyGroups(gPropertyGroup);
      foreach (var o in new List<string>() {"ConsoleSourceGHS", "ConsoleSinkGHS"}) {
        mCreateAssemblyGroupResult.GClassBase.AddTConstructorAutoPropertyGroup(
          mCreateAssemblyGroupResult.GPrimaryConstructorBase.Philote, o, gPropertyGroupId: gPropertyGroup.Philote);
      }
      #endregion
      #region Add the MethodGroup for this service
      var gMethodGroup =
        new GMethodGroup(
          gName:
          $"MethodGroup specific to {mCreateAssemblyGroupResult.GClassBase.GName}");
      IGMethod gMethod;
      gMethod = CreateConsoleSourceReadLineAsyncAsObservableMethod();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      gMethod = MCreateWriteMethodInConsoleMonitor();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      //gMethod = MCreateWriteAsyncMethodInConsoleMonitor();
      //gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      mCreateAssemblyGroupResult.GClassBase.AddMethodGroup(gMethodGroup);
      #endregion
      #region Add References used by the Titular Derived and Titular Base CompilationUnits to the ProjectUnit
      #region Add References used by both the Titular Derived and Titular Base CompilationUnits
      foreach (var o in new List<IGItemGroupInProjectUnit>() {
          ReactiveUtilitiesReferencesItemGroupInProjectUnit(),
          new GItemGroupInProjectUnit(
            "References used by both the {Derived} and {Base}",
            "References to the ConsoleSourceGHS and ConsoleSinkGHS Interfaces, used by both the used by both the {Derived CompilationUnit} and {Base CompilationUnit}",
            new GBody(new List<string>() {
              "<PackageReference Include=\"ConsoleSourceGHS.Interfaces\" />",
              "<PackageReference Include=\"ConsoleSinkGHS.Interfaces\" />",
            }))
        }
      ) {
        mCreateAssemblyGroupResult.GTitularAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits
          .Add(o.Philote, o);
      }
      #endregion
      #region Add References unique to the Titular Base CompilationUnit
      foreach (var o in new List<IGItemGroupInProjectUnit>() { }
      ) {
        mCreateAssemblyGroupResult.GTitularAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits
          .Add(o.Philote, o);
      }
      #endregion
      #endregion
      /*******************************************************************************/
      #region Update the Interface Assembly for this service
      #region Add UsingGroups for the Titular Derived Interface CompilationUnit and Titular Base Interface CompilationUnit
      #region Add UsingGroups common to both the Titular Derived Interface CompilationUnit and the Titular Base Interface CompilationUnit
      gUsingGroup =
        new GUsingGroup(
          $"UsingGroups common to both {mCreateAssemblyGroupResult.GTitularInterfaceDerivedCompilationUnit.GName} and {mCreateAssemblyGroupResult.GTitularInterfaceBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {
        $"{baseNamespaceName}ConsoleSinkGHS", $"{baseNamespaceName}ConsoleSourceGHS"
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.GTitularInterfaceDerivedCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote,
        gUsingGroup);
      mCreateAssemblyGroupResult.GTitularInterfaceBaseCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote,
        gUsingGroup);
      #endregion
      #region Add UsingGroups specific to the Titular Base Interface
      #endregion
      #endregion
      #region Add References for the Titular Interface ProjectUnit
      #region Add References common to both the Titular Derived Interface and Titular Base Interface
      foreach (var o in new List<IGItemGroupInProjectUnit>() {
          ReactiveUtilitiesReferencesItemGroupInProjectUnit(),
          new GItemGroupInProjectUnit(
            "References used by both the {Derived} and {Base}",
            "References to the ConsoleSourceGHS and ConsoleSinkGHS Interfaces, used by both the used by both the {Derived CompilationUnit} and {Base CompilationUnit}",
            new GBody(new List<string>() {
              "<PackageReference Include=\"ConsoleSourceGHS.Interfaces\" />",
              "<PackageReference Include=\"ConsoleSinkGHS.Interfaces\" />",
            })),
        }
      ) {
        mCreateAssemblyGroupResult.gTitularInterfaceAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits
          .Add(o.Philote, o);
      }
      #endregion
      #region Add References unique to the Titular Base Interface CompilationUnit
      #endregion
      #endregion
      #endregion
      #region Finalize the GHHS
      GAssemblyGroupGHHSFinalizer(mCreateAssemblyGroupResult);
      #endregion
      return mCreateAssemblyGroupResult.GAssemblyGroup;
    }
    /*******************************************************************************/
    /*******************************************************************************/
    static IGMethod MCreateWriteAsyncMethodInConsoleMonitor(string gAccessModifier = "") {
      var gMethodArgumentList = new List<IGArgument>() {
        new GArgument("mesg", "string"), new GArgument("ct", "CancellationTokenFromCaller?")
      };
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
      foreach (var o in gMethodArgumentList) {
        gMethodArguments.Add(o.Philote, o);
      }
      return new GMethod(
        new GMethodDeclaration(gName: "WriteAsync", gType: "Task",
          gVisibility: "public", gAccessModifier: gAccessModifier + " async", isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            "StateMachine.Fire(Trigger.WriteAsyncStarted);",
            "ct?.ThrowIfCancellationRequested();",
            "await ConsoleSinkGHS.WriteAsync(mesg, ct);",
            "StateMachine.Fire(Trigger.WriteAsyncFinished);",
            "return Task.CompletedTask;"
          }),
        new GComment(new List<string>() {
          "// Used to asynchronously write a string to the WriteAsync method of the ConsoleSink service"
        }));
    }
    static IGMethod MCreateWriteMethodInConsoleMonitor(string gAccessModifier = "") {
      var gMethodArgumentList = new List<IGArgument>() {
        new GArgument("mesg", "string"), new GArgument("ct", "CancellationTokenFromCaller?")
      };
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
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
            "ConsoleSinkGHS.Write(mesg, ct);",
            "StateMachine.Fire(Trigger.WriteFinished);",
          }),
        new GComment(new List<string>() {"// Used to write a string to Write method of the ConsoleSink service"}));
    }
    static IGMethod CreateConsoleSourceReadLineAsyncAsObservableMethod(string gAccessModifier = "") {
      var gMethodArgumentList = new List<IGArgument>() {
        // None
      };
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
      foreach (var o in gMethodArgumentList) {
        gMethodArguments.Add(o.Philote, o);
      }
      return new GMethod(
        new GMethodDeclaration(gName: "ConsoleReadLineAsyncAsObservable", gType: "IObservable<string>",
          gVisibility: "public", gAccessModifier: gAccessModifier, isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            @"     return",
            @"         Observable",
            @"             .FromAsync(() => ConsoleSourceGHS.ConsoleReadLineAsyncAsObservable()) // This is actually a BLOCKING operation, see ?? for workaround",
            @"             .Repeat()",
            @"             .Publish()",
            @"             .RefCount()",
            @"             .SubscribeOn(Scheduler.Default);",
          }),
        new GComment(new List<string>() {
          "// Convert the ConsoleSourceGHS.ConsoleReadLineAsyncAsObservable into an IObservable in this service",
        }));
    }
  }
}
