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
    public static GAssemblyGroup MConsoleSinkGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default) {
      return MConsoleSinkGHS(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, new GPatternReplacement()  );
    }
    public static GAssemblyGroup MConsoleSinkGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      var mCreateAssemblyGroupResult = MAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, _gPatternReplacement);
      #region Initial StateMachine Configuration for this specific service
      mCreateAssemblyGroupResult.gPrimaryConstructorBase.GStateConfigurations.AddRange(
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
      #region Add UsingGroups to the Titular Derived and Titular Base CompilationUnits 
      #region Add UsingGroups common to both the Titular Derived and Titular Base CompilationUnits
      #endregion
      #region Add UsingGroups specific to the Titular Base CompilationUnit
      #endregion
      #endregion
      #region Injected PropertyGroup For ConsoleSinkAndConsoleSource
      #endregion
      #region Add the MethodGroup containing new methods provided by this library to the Titular Base CompilationUnit
      var gMethodGroup =
        new GMethodGroup(
          gName:
          $"MethodGroup specific to {mCreateAssemblyGroupResult.gClassBase.GName}");
      GMethod gMethod;
      gMethod = MCreateWriteMethodInConsoleSink();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      mCreateAssemblyGroupResult.gClassBase.AddMethodGroup(gMethodGroup);
      #endregion
      #region Add additional classes provided by this library to the Titular Base CompilationUnit
      #endregion
      #region Add References used by the Titular Derived and Titular Base CompilationUnits to the ProjectUnit 
      #region Add References used by both the Titular Derived and Titular Base CompilationUnits
      #endregion
      #region Add References unique to the Titular Base CompilationUnit
      #endregion
      #endregion
      /*******************************************************************************/
      #region Update the Interface Assembly for this service
      #region Add UsingGroups for the Titular Derived Interface and Titular Base Interface
      #region Add UsingGroups common to both the Titular Derived Interface and the Titular Base Interface
      #endregion
      #region Add UsingGroups specific to the Titular Base Interface
      #endregion
      #endregion
      #region Add References for the Titular Interface ProjectUnit
      #region Add References common to both the Titular Derived Interface and Titular Base Interface
      #endregion
      #region Add References unique to the Titular Base Interface CompilationUnit
      #endregion
      #endregion
      #endregion
      #region Finalize the GHHS
      GAssemblyGroupGHHSFinalizer(mCreateAssemblyGroupResult);
      #endregion
      return mCreateAssemblyGroupResult.gAssemblyGroup;
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
