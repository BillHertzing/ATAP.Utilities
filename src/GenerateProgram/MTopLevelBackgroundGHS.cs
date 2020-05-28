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
    public static GAssemblyGroup MTopLevelBackgroundGHS(
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;

      var gAssemblyGroupName = "TopLevelBackgroundGHS";
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
      #region Use MConsoleMonitorClient to implement the  ConsoleMonitor Pattern (includes adding the Transition from basic GHHS to ConsoleMonitorClient to the diGraph)
      MConsoleMonitorClient(gAssemblyGroup, titularAssemblyUnitLookupPrimaryConstructorResults, baseNamespaceName);
      #endregion
      #region Initial StateMachine Configuration for this specific service
      titularAssemblyUnitLookupPrimaryConstructorResults.gMethods.First().GStateConfigurations.AddRange(
        new List<GStateConfiguration>() {
          new GStateConfiguration(
            gStateTransitions: new List<string>() {
              @"WaitingForInitialization ->InitiateContactWithConsoleMonitor [label = ""InitializationCompleteReceived""]", // ToDo: move this to ConsoleMonitorClient
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
        // None
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

  }
}
