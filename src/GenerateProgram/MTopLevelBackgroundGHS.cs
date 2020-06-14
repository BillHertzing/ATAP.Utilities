using System;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GUsingGroupExtensions;
using static GenerateProgram.GAttributeGroupExtensions;
using static GenerateProgram.Lookup;
//using AutoMapper.Configuration;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblyGroup MTopLevelBackgroundGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default) {
      return MTopLevelBackgroundGHS(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, new GPatternReplacement()  );
    }

    public static GAssemblyGroup MTopLevelBackgroundGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      var mCreateAssemblyGroupResult = MAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, _gPatternReplacement);
      #region Initial StateMachine Configuration
      mCreateAssemblyGroupResult.gPrimaryConstructorBase.GStateConfiguration.GDOTGraphStatements.Add(
    @"
          WaitingForInitialization ->InitiateContactWithConsoleMonitor [label = ""InitializationCompleteReceived""] // ToDo: move this to ConsoleMonitorClient
          Connected -> Execute [label = ""inputline == 1""]
          Connected -> Relinquish [label = ""inputline == 99""]
          Connected -> Editing [label = ""inputline == 2""]
          Editing -> Connected [label=""EditingComplete""]
          Execute -> Connected [label = ""LongRunningTaskStartedNotificationSent""]
          Relinquish -> Contacted [label = ""RelinquishNotificationAcknowledgementReceived""]
          Connected ->ShutdownStarted [label = ""CancellationTokenActivated""]
          Editing->ShutdownStarted[label = ""CancellationTokenActivated""]
          Execute->ShutdownStarted[label = ""CancellationTokenActivated""]
          Relinquish->ShutdownStarted[label = ""CancellationTokenActivated""]
          Connected -> ServiceFaulted [label = ""ExceptionCaught""]
          Editing ->ServiceFaulted [label = ""ExceptionCaught""]
          Execute ->ServiceFaulted [label = ""ExceptionCaught""]
          Relinquish ->ServiceFaulted [label = ""ExceptionCaught""]
          Connected ->ShutdownStarted [label = ""StopAsyncActivated""]
          Editing ->ShutdownStarted [label = ""StopAsyncActivated""]
          Execute ->ShutdownStarted [label = ""StopAsyncActivated""]
          Relinquish ->ShutdownStarted [label = ""StopAsyncActivated""]
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
      #region Add the MethodGroup containing new methods provided by this library to the Titular Base CompilationUnits 
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
      #endregion
       /* ************************************************************************************ */
      #region Upate the ProjectUnits in both the Titular AssemblyUnit and Titular InterfacesAssemblyUnit
      #region Add References for the Titular Interface ProjectUnit
      #region Add References common to both the Titular Derived Interface and Titular Base Interface
      #endregion
      #region Add References unique to the Titular Base Interface CompilationUnit
      #endregion
      #endregion
      #endregion
      #region Finalize the GHHS
      GAssemblyGroupGHBSFinalizer(mCreateAssemblyGroupResult);
      #endregion
      return mCreateAssemblyGroupResult.gAssemblyGroup;
    }
    /*******************************************************************************/
    /*******************************************************************************/

    public static (GBody, GComment) MCreateProcessInputMethodForTopLevelBackgroundGHS() {
      GBody gBody = new GBody(gStatements: new List<string>() {"#region TBD", " #endregion",});
      GComment gComment = new GComment(new List<string>() {
        "///  Used to process inputStrings from the ConsoleMonitorPattern"
      });
      return (gBody:gBody, gComment:gComment);
    }
  }
}
