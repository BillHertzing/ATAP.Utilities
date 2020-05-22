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
    public static GAssemblyGroup MTopLevelBackgroundService(
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;

      var gAssemblyGroupName = "TopLevelBackgroundService";
      var gAssemblyGroup = GAssemblyGroupGHBSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, _gPatternReplacement);
      #region Declare and populate the initial rawDiGraph, which handles basic states for a GHHS
      List<string> rawDiGraph = new List<string>() {
        @"WaitingForInitialization ->ServiceFaulted [label = ""AnyException""]",
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
      #region Add Transition from basic GHHS to ConsoleMonitorClient to the diGraph
       rawDiGraph = new List<string>() {
        "WaitingForInitialization ->InitiateContactWithConsoleMonitor [label = \"InitializationCompleteReceived\"]",
      };
      #endregion
      #region Use MConsoleMonitorClient to implement the  ConsoleMonitor Pattern
      MConsoleMonitorClient(gAssemblyGroup,lookupResultsForTitularBase,baseNamespaceName,rawDiGraph);
      #endregion
      #region StateMachine Configuration for this specific service
      rawDiGraph.AddRange(new List<string>(){
        @"Connected -> Execute [label = ""inputline == 1""]",
        @"Connected -> Relinquish [label = ""inputline == 99""]",
        @"Connected -> Editing [label = ""inputline == 2""]",
        @"Editing -> Connected [label=""EditingComplete""]",
        @"Execute -> Connected [label = ""LongRunningTaskStartedNotificationSent""]",
        @"Relinquish -> Contacted [label = ""RelinquishNotificationAcknowledgementReceived""]",
        @"Connected ->ShutdownStarted [label = ""CancellationTokenActivated""]",
        @"Editing->ShutdownStarted[label = ""CancellationTokenActivated""]",
        @"Execute->ShutdownStarted[label = ""CancellationTokenActivated""]",
        @"Relinquish->ShutdownStarted[label = ""CancellationTokenActivated""]",
        @"Connected -> ServiceFaulted [label = ""ExceptionCaught""]",
        @"Editing ->ServiceFaulted [label = ""ExceptionCaught""]",
        @"Execute ->ServiceFaulted [label = ""ExceptionCaught""]",
        @"Relinquish ->ServiceFaulted [label = ""ExceptionCaught""]",
        @"Connected ->ShutdownStarted [label = ""StopAsyncActivated""]",
        @"Editing ->ShutdownStarted [label = ""StopAsyncActivated""]",
        @"Execute ->ShutdownStarted [label = ""StopAsyncActivated""]",
        @"Relinquish ->ShutdownStarted [label = ""StopAsyncActivated""]",
      });
      MStateMachineDetails(lookupResultsForTitularBase, rawDiGraph);
      #endregion

      #region Add the UsingGroup for this service
      var gUsingGroup = new GUsingGroup($"Usings specific to {lookupResultsForTitularBase.gCompilationUnits.First().GName}");
      foreach (var gName in new List<string>() {
        // none
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      lookupResultsForTitularBase.gCompilationUnits.First().GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      #endregion
      #region Add the MethodGroup for this service
      //var gMethodGroup =
      //  new GMethodGroup(gName: $"MethodGroup specific to {lookupResultsForTitularBase.gCompilationUnits.First().GName}");
      //GMethod gMethod;
      //gMethod = MNone();
      //gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      //lookupResultsForTitularBase.gClasss.First().AddMethodGroup(gMethodGroup);
      #endregion

      #region References to be added to the Titular ProjectUnit
      #region References common to both Titular and Base
      foreach (var o in new List<GItemGroupInProjectUnit>() {
        // None
        }
      ) {
        lookupResultsForTitularBase.gAssemblyUnits.First().GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o);
      }
      #endregion
      #region References unique to Base
      foreach (var o in new List<GItemGroupInProjectUnit>() {
      //None
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
          // None
        }
      ) {
        lookupResultsForProjectAssembly.gProjectUnits.First().GItemGroupInProjectUnits.Add(o.Philote, o);
      }
      #endregion
      #endregion
      return gAssemblyGroup;
    }
    /*******************************************************************************/
    /*******************************************************************************/

  }
}
