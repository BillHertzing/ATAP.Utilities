using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.StringConstants;
//using AutoMapper.Configuration;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GUsingGroupExtensions;
using System;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblyGroup MConsoleSink(
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default
      ) {
      var gAssemblyGroupName = "ConsoleSink";

      var gAssemblyGroup = GAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespace, true);

      // Modify it
      #region StateMachine Configuration
      /*
        * digraph finite_state_machine {
        WaitingForInitialization ->InitiateContact [label = "InitializationCompleteReceived"];
        InitiateContact -> WaitingForContact [label = "ConsoleMonitorNotifyConsoleSinkReadySent"];
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
      // ToDo: Look up the right class via the Database
      GNamespace rightGNamespace = default;
      GClass rightGClass = default;
      foreach (var gAU in gAssemblyGroup.GAssemblyUnits) {
        foreach (var gCU in gAU.Value.GCompilationUnits) {
          foreach (var gNs in gCU.Value.GNamespaces) {
            foreach (var gCl in gNs.Value.GClasss) {
              if (gCl.Value.GName == "AssemblyUnitNameReplacementPatternBase") {
                rightGNamespace = gNs.Value;
                rightGClass = gCl.Value;
                // ToDo: break out to the outermost loop
              }
            }
          }
        }
      }
      //var gClass = gAssemblyGroup.GAssemblyUnits.AsQueryable().Where( )Select(x => x.State)"
      if (rightGClass == default) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }

      // Add the State enumeration and its members to the base class
      // Add the Trigger enumeration and its members to the base class
      // Add a StaticVariable to the base class
      var gStaticVariable = new GStaticVariable("stateConfigurations", gType: "StateConfiguration", gBody: new GBody(new List<string>()));
      rightGClass.GStaticVariables.Add(gStaticVariable.Philote, gStaticVariable);
      // Define the properties for the StateConfiguration class
      var gPropertys = new Dictionary<Philote<GProperty>, GProperty>();
      var gProperty = new GProperty("State", "State", gAccessors: "{get;}");
      gPropertys.Add(gProperty.Philote, gProperty);
      gProperty = new GProperty("Trigger", "Trigger", gAccessors: "{get;}");
      gPropertys.Add(gProperty.Philote, gProperty);
      gProperty = new GProperty("NextState", "State", gAccessors: "{get;}");
      gPropertys.Add(gProperty.Philote, gProperty);

      // Add a StateConfiguration class to the base Compilation unit's namespace
      var stateConfigurationClass = new GClass(gName: "StateConfiguration", gPropertys: gPropertys);
      rightGNamespace.GClasss.Add(stateConfigurationClass.Philote, stateConfigurationClass);
      // Add a stateConfigurationsProperty to the base class
      var stateConfigurationsProperty = new GProperty("StateConfigurations", gType: "List<StateConfiguration>", gAccessors: "{get;}");
      rightGClass.AddProperty(stateConfigurationsProperty);
      // By Convention add a method to the base class
      // StateMachine Configuration
      var gBody = new GBody(new List<string>() {
          "// attribution :https://github.com/dhrobbins/ApprovaFlow/blob/master/ApprovaFlow/ApprovaFlow/ApprovaFlow/Workflow/WorkflowProcessor.cs",
          "//  Get a distinct list of states with a trigger from the stateConfigurations static variable",
          "//  State => Trigger => TargetState",
          "var states = StateConfigurations.AsQueryable()",
          ".Select(x => x.State)",
          ".Distinct()",
          ".Select(x => x)",
          ".ToList();",
          "//  Get each trigger for each state",
          "states.ForEach(state =>{",
          "var triggers = StateConfigurations.AsQueryable()",
          ".Where(config => config.State == state)",
          ".Select(config => new { Trigger = config.Trigger, TargetState = config.TargetState })",
          ".ToList();",
          "triggers.ForEach(trig => {",
          "StateMachine.Configure(state).Permit(trig.Trigger, trig.TargetState);",
          "});",

        });
      var gMethodDeclaration = new GMethodDeclaration(gName: "ConfigureState", gType: "void", gAccessModifier: "override");
      var gMethod = new GMethod(gMethodDeclaration, gBody);

      rightGClass.GMethods.Add(gMethod.Philote, gMethod);

      #endregion

      return gAssemblyGroup;
    }
  }
}
