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
    public static GAssemblyGroup MFileSystemWatcherGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default) {
      return MFileSystemWatcherGHS(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, new GPatternReplacement()  );
    }

    public static GAssemblyGroup MFileSystemWatcherGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      var mCreateAssemblyGroupResult = MAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, _gPatternReplacement);
      #region Initial StateMachine Configuration
      mCreateAssemblyGroupResult.gPrimaryConstructorBase.GStateConfiguration.GDOTGraphStatements.Add(
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
          $"UsingGroup common to both  {mCreateAssemblyGroupResult.gTitularDerivedCompilationUnit.GName} and {mCreateAssemblyGroupResult.gTitularBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {
        "System.IO"
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.gTitularDerivedCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      mCreateAssemblyGroupResult.gTitularBaseCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Add UsingGroups specific to the Titular Base CompilationUnit
      gUsingGroup =
        new GUsingGroup(
          $"UsingGroup specific to {mCreateAssemblyGroupResult.gTitularBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {
        "System.IO"
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.gTitularBaseCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
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
      gMethod = MCreateRequestAFileSystemWatcher();
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
      gUsingGroup =
        new GUsingGroup($"UsingGroups common to both {mCreateAssemblyGroupResult.gTitularInterfaceDerivedCompilationUnit.GName} and {mCreateAssemblyGroupResult.gTitularInterfaceBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {
        "System.IO",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.gTitularInterfaceDerivedCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      mCreateAssemblyGroupResult.gTitularInterfaceBaseCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
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
    static GMethod MCreateRequestAFileSystemWatcher(string gAccessModifier = "virtual") {
      var gMethodArgumentList = new List<GArgument>() {
        new GArgument("requestorPhilote", "object"),
        new GArgument("callback", "object"),
        new GArgument("fileSystemWatcherSignil", "object"),
        new GArgument("ct", "CancellationToken?")
      };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
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