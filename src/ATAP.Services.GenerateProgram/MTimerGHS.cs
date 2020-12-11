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
    public static GAssemblyGroup MTimerGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true) {
      return MTimerGHS(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, hasInterfaces, new GPatternReplacement()  );
    }
    public static GAssemblyGroup MTimerGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      var mCreateAssemblyGroupResult = MAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, hasInterfaces, _gPatternReplacement);
      #region Initial StateMachine Configuration
      mCreateAssemblyGroupResult.gPrimaryConstructorBase.GStateConfiguration.GDOTGraphStatements.Add(
    @"
          WaitingForInitialization -> WaitingForARequestForATimer [label = ""InitializationCompleteReceived""]
          WaitingForARequestForATimer -> RespondingToARequestForATimer [label = ""TimerRequested""]
          RespondingToARequestForATimer -> WaitingForARequestForATimer [label = ""TimerAllocatedAndSent""]
          RespondingToARequestForATimer -> WaitingForARequestForATimer [label = ""CancellationTokenActivated""]
          WaitingForARequestForATimer -> ServiceFaulted [label = ""ExceptionCaught""]
          RespondingToARequestForATimer ->ServiceFaulted [label = ""ExceptionCaught""]
          WaitingForARequestForATimer ->ShutdownStarted [label = ""CancellationTokenActivated""]
          RespondingToARequestForATimer ->ShutdownStarted [label = ""StopAsyncActivated""]
        "
      );
      #endregion
      #region Add UsingGroups to the Titular Derived and Titular Base CompilationUnits 
      #region Add UsingGroups common to both the Titular Derived and Titular Base CompilationUnits
      #endregion
      #region Add UsingGroups specific to the Titular Base CompilationUnit
      #endregion
      #endregion
      #region Injected PropertyGroup For ConsoleSinkAndConsoleSource
      #endregion
      #region Add the MethodGroup for this service
      var gMethodGroup =
        new GMethodGroup(
          gName:
          $"MethodGroup specific to {mCreateAssemblyGroupResult.gClassBase.GName}");
      GMethod gMethod;
      gMethod = MCreateRequestATimer();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      mCreateAssemblyGroupResult.gClassBase.AddMethodGroup(gMethodGroup);
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
    static GMethod MCreateRequestATimer(string gAccessModifier = "virtual") {
      var gMethodArgumentList = new List<GArgument>() {
        new GArgument("requestorPhilote", "object"),
        new GArgument("callback", "object"),
        new GArgument("timerSignil", "object"),
        new GArgument("ct", "CancellationToken?")
      };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in gMethodArgumentList) {
        gMethodArguments.Add(o.Philote, o);
      }
      return new GMethod(
        new GMethodDeclaration(gName: "RequestATimer", gType: "ServiceTimer",
          gVisibility: "public", gAccessModifier: gAccessModifier, isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            "StateMachine.Fire(Trigger.TimerRequestStarted);",
            "ct?.ThrowIfCancellationRequested();",
            "",
            "StateMachine.Fire(Trigger.TimerRequestFinished);",
          }),
        new GComment(new List<string>() {"// Used to request a managed ServiceTimer"}));
    }
  }
}
