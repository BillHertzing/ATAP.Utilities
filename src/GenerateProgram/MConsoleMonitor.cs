using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyGroupExtensions;
//using AutoMapper.Configuration;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GAttributeGroupExtensions;

using static GenerateProgram.GItemGroupInProjectUnitExtensions;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblyGroup MConsoleMonitor(
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default
      ) {
      var gAssemblyGroupName = "ConsoleMonitor";
      var gAssemblyGroup = GAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespace);

      #region StateMachine Configuration
      // Get the namespace, and class, to which the gEnumerationGroup and GStaticVariable will be added
      GNamespace gNamespace = default;
      GClass gClass = default;
      // ToDo: Look up the right class via the Database
      foreach (var gAU in gAssemblyGroup.GAssemblyUnits) {
        foreach (var gCU in gAU.Value.GCompilationUnits) {
          foreach (var gNs in gCU.Value.GNamespaces) {
            foreach (var gCl in gNs.Value.GClasss) {
              if (gCl.Value.GName == "AssemblyUnitNameReplacementPatternBase") {
                gNamespace = gNs.Value;
                gClass = gCl.Value;
                // ToDo: break out to the outermost loop
              }
            }
          }
        }
      }
      if (gClass == default) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      /*
        * digraph finite_state_machine {
        WaitingForInitialization -> WaitForConsoleSourceAndSink [label = "InitializationCompleteReceived"];
        WaitForConsoleSourceAndSink -> WaitingForContact [label = "ConsoleSourceAndSinkConnectedComplete"];
        WaitingForContact -> WaitingForContactTimeoutFailure [label = "ConsoleMonitorNotifyConsoleSinkReadySentTimeout"];
        WaitingForContact -> Connected [label = "ConsoleMonitorNotifyConsoleSinkReadyAcknowledgementReceived"];
        Connected -> Write [label = "WriteMethodCalled"];
        Connected -> WriteASync [label = "WriteAsyncMethodCalled"]
        Write -> Connected [label = "WriteMethodCompleted"];
        Write -> ServiceFaulted [label="WriteMethodExceptionCaught"];
        WriteAsync -> Connected [label = "WriteAsyncMethodCalled"];
        WriteAsync -> ServiceFaulted [label="WriteAsyncMethodReturnedTaskFaulted"];
        WaitingForInitialization ->ShuttingDown [label = "CancellationTokenActivated"];
        InitiateContact ->ShuttingDown [label = "CancellationTokenActivated"];
        WaitingForContact ->ShuttingDown [label = "CancellationTokenActivated"];
        WaitingForContactTimeoutFailure ->ShutdownStarted [label = "CancellationTokenActivated"];
        Connected ->ShutdownStarted [label = "CancellationTokenActivated"];
        Write ->ShutdownStarted [label = "CancellationTokenActivated"];
        WriteAsync ->ShutdownStarted [label = "CancellationTokenActivated"];
        ServiceFaulted ->ShutdownStarted [label = "CancellationTokenActivated"];
        ShutdownStarted->ShutDownComplete [label = "AllShutDownStepsCompleted"];
        }
      */
      #region StateMachine EnumerationGroups
      var gEnumerationGroup = new GEnumerationGroup(gName: "State and Trigger Enumerations for StateMachine");
      #region State Enumeration
      #region State Enumeration members
      var gEnumerationMemberList = new List<GEnumerationMember>();
      Dictionary<Philote<GAttributeGroup>, GAttributeGroup> gAttributeGroups =
        new Dictionary<Philote<GAttributeGroup>, GAttributeGroup>();
      GAttributeGroup gAttributeGroup = CreateLocalizableEnumerationAttributeGroup(description: "Power-On State - waiting until minimal initialization condition has been met",visualDisplay: "Waiting For Initialization",visualSortOrder: 1);
      gAttributeGroups[gAttributeGroup.Philote] = gAttributeGroup;
      gEnumerationMemberList.Add(
        new GEnumerationMember(gName: "WaitingForInitialization", gValue: 1,
          gAttributeGroups: gAttributeGroups
        ));
      gAttributeGroups = new Dictionary<Philote<GAttributeGroup>, GAttributeGroup>();
      gAttributeGroup = CreateLocalizableEnumerationAttributeGroup(description: "Wait until both a ConsoleSource and a ConsoleSink service has registered with us",visualDisplay: "Wait For ConsoleSource And ConsoleSink", visualSortOrder: 2);
      gAttributeGroups[gAttributeGroup.Philote] = gAttributeGroup;
      gEnumerationMemberList.Add(new GEnumerationMember(gName: "WaitForConsoleSourceAndSink", gValue: 2,
        gAttributeGroups: gAttributeGroups
      ));

      var gEnumerationMembers = new Dictionary<Philote<GEnumerationMember>, GEnumerationMember>();
      foreach (var o in gEnumerationMemberList) {
        gEnumerationMembers[o.Philote] = o;
      }
      #endregion
      var gEnumeration =
        new GEnumeration(gName: "State", gVisibility: "public", gInheritance: "", gEnumerationMembers: gEnumerationMembers);
      gEnumerationGroup.GEnumerations[gEnumeration.Philote] = gEnumeration;
      #endregion
      #region Trigger Enumeration
      #region Trigger Enumeration members
      gEnumerationMemberList = new List<GEnumerationMember>();
      gAttributeGroups = new Dictionary<Philote<GAttributeGroup>, GAttributeGroup>();
      gAttributeGroup = CreateLocalizableEnumerationAttributeGroup(description: "The minimal initialization conditions have been met",visualDisplay: "Initialization Complete Received",visualSortOrder: 2);
      gAttributeGroups[gAttributeGroup.Philote] = gAttributeGroup;
      gEnumerationMemberList.Add(
        new GEnumerationMember(gName: "InitializationCompleteReceived", gValue: 1,
          gAttributeGroups: gAttributeGroups
        ));

      gEnumerationMembers = new Dictionary<Philote<GEnumerationMember>, GEnumerationMember>();
      foreach (var o in gEnumerationMemberList) {
        gEnumerationMembers[o.Philote] = o;
      }
      #endregion
      gEnumeration =
       new GEnumeration(gName: "Trigger", gVisibility: "public", gInheritance: "", gEnumerationMembers: gEnumerationMembers);
      gEnumerationGroup.GEnumerations[gEnumeration.Philote] = gEnumeration;
      #endregion
      gNamespace.AddEnumerationGroup(gEnumerationGroup);

      #endregion
      #region StateMachine Transitions
      // Add a StaticVariable to the class
      var gStaticVariable = new GStaticVariable("stateConfigurations", gType: "List<StateConfiguration>", gBody: new GBody(new List<string>(){
        "new List<StateConfiguration>(){",
       "new StateConfiguration(State.WaitingForInitialization,Trigger.InitializationCompleteReceived,State.InitiateContact)",
        "}"
      }));
      gClass.GStaticVariables.Add(gStaticVariable.Philote, gStaticVariable);

      #endregion
      #endregion

      #region AssemblyGroup referenced Packages and Projects
      GAssemblyUnit gAssemblyUnit = default;
      // References used by the Base Assembly
      // ToDo: Look up the right AssemblyUnit via the Database
      foreach (var gAU in gAssemblyGroup.GAssemblyUnits) {
        foreach (var gCU in gAU.Value.GCompilationUnits) {
          if (gCU.Value.GName == "AssemblyUnitNameReplacementPatternBase") {
            gAssemblyUnit = gAU.Value;
            // ToDo: break out to the outermost loop
          }
        }
      }
      if (gAssemblyUnit == default) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      foreach (var o in new List<GItemGroupInProjectUnit>() {
        ProjectReferenceItemGroupInProjectUnitForReactiveUtilities(),
        new GItemGroupInProjectUnit("ReferencesForConsoleMonitor",
          "References to the ConsoleSource and ConsoleSink", new GBody(new List<string>() {
            "<PackageReference Include=\"ConsoleSource\" />",
            "<PackageReference Include=\"ConsoleSink\" />",
          }))}
      ) {
        gAssemblyGroup.GAssemblyUnits[gAssemblyUnit.Philote].GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote,o);
      }

      // References used by the Interface Assembly
      // ToDo: Look up the right AssemblyUnit via the Database
      foreach (var gAU in gAssemblyGroup.GAssemblyUnits) {
        foreach (var gCU in gAU.Value.GCompilationUnits) {
          if (gCU.Value.GName == "AssemblyUnitNameReplacementPatternBase.Interfaces") {
            gAssemblyUnit = gAU.Value;
            // ToDo: break out to the outermost loop
          }
        }
      }
      if (gAssemblyUnit == default) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      foreach (var o in new List<GItemGroupInProjectUnit>() {
          ProjectReferenceItemGroupInProjectUnitForReactiveUtilities(),
        }
      ) {
        gAssemblyGroup.GAssemblyUnits[gAssemblyUnit.Philote].GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote,o);
      }
      #endregion

      return gAssemblyGroup;
    }
  }
}
