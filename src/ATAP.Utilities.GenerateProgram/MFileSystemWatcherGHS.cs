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
    public static IGAssemblyGroup MFileSystemWatcherGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true) {
      return MFileSystemWatcherGHS(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, hasInterfaces, new GPatternReplacement()  );
    }

    public static IGAssemblyGroup MFileSystemWatcherGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,bool hasInterfaces = true,
      IGPatternReplacement gPatternReplacement = default) {
      IGPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      var mCreateAssemblyGroupResult = MAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, hasInterfaces, _gPatternReplacement);
      #region Initial StateMachine Configuration
      mCreateAssemblyGroupResult.GPrimaryConstructorBase.GStateConfiguration.GDOTGraphStatements.Add(
        @"
              WaitingForInitialization -> WaitingForARequestForAFileSystemWatcher [label = ""InitializationCompleteReceived""]
              WaitingForARequestForAFileSystemWatcher -> RespondingToARequestForAFileSystemWatcher [label = ""FileSystemWatcherRequested""]
              RespondingToARequestForAFileSystemWatcher -> WaitingForARequestForAFileSystemWatcher [label = ""FileSystemWatcherAllocatedAndSent""]
              RespondingToARequestForAFileSystemWatcher -> WaitingForARequestForAFileSystemWatcher [label = ""CancellationTokenActivated""]
              WaitingForARequestForAFileSystemWatcher -> ServiceFaulted [label = ""ExceptionCaught""]
              RespondingToARequestForAFileSystemWatcher ->ServiceFaulted [label = ""ExceptionCaught""]
              WaitingForARequestForAFileSystemWatcher ->ShutdownStarted [label = ""CancellationTokenActivated""]
              RespondingToARequestForAFileSystemWatcher ->ShutdownStarted [label = ""StopAsyncActivated""]
            "
      );
      #endregion
      #region Add UsingGroups to the Titular Derived and Titular Base CompilationUnits
      #region Add UsingGroups common to both the Titular Derived and Titular Base CompilationUnits
      var gUsingGroup =
        new GUsingGroup(
          $"UsingGroup common to both  {mCreateAssemblyGroupResult.GTitularDerivedCompilationUnit.GName} and {mCreateAssemblyGroupResult.GTitularBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {
        "System.IO"
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
        "System.IO"
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.GTitularBaseCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #endregion
      #region Injected PropertyGroup For ConsoleSinkAndConsoleSource
      #endregion
      #region Add the MethodGroup for this service
      var gMethodGroup =
        new GMethodGroup(
          gName:
          $"MethodGroup specific to {mCreateAssemblyGroupResult.GClassBase.GName}");
      var gMethod = MCreateRequestAFileSystemWatcher();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      mCreateAssemblyGroupResult.GClassBase.AddMethodGroup(gMethodGroup);
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
      gUsingGroup =
        new GUsingGroup($"UsingGroups common to both {mCreateAssemblyGroupResult.GTitularInterfaceDerivedCompilationUnit.GName} and {mCreateAssemblyGroupResult.GTitularInterfaceBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {
        "System.IO",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.GTitularInterfaceDerivedCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      mCreateAssemblyGroupResult.GTitularInterfaceBaseCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
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
      return mCreateAssemblyGroupResult.GAssemblyGroup;
    }
    /*******************************************************************************/
    /*******************************************************************************/
    static IGMethod MCreateRequestAFileSystemWatcher(string gAccessModifier = "virtual") {
      var gMethodArgumentList = new List<IGArgument>() {
        new GArgument("requestorPhilote", "object"),
        new GArgument("callback", "object"),
        new GArgument("fileSystemWatcherSignil", "object"),
        new GArgument("ct", "CancellationToken?")
      };
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
      foreach (var o in gMethodArgumentList) {
        gMethodArguments.Add(o.Philote, o);
      }
      return new GMethod(
        new GMethodDeclaration(gName: "RequestAFileSystemWatcher", gType: "FileSystemWatcher",
          gVisibility: "public", gAccessModifier: gAccessModifier, isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            "StateMachine.Fire(Trigger.FileSystemWatcherRequestStarted);",
            "ct?.ThrowIfCancellationRequested();",
            "",
            "StateMachine.Fire(Trigger.FileSystemWatcherRequestFinished);",
          }),
        new GComment(new List<string>() {"// Used to request a managed ServiceFileSystemWatcher"}));
    }
  }
}
