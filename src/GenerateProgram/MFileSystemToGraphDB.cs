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
    public static GAssemblyGroup MFileSystemToGraphDB(
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default
      ) {
      var gAssemblyGroupName = "FileSystemToGraphDataBase";

      var gAssemblyGroup = GAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespace, true);

      // Modify it
      #region StateMachine Configuration
      /*
        * digraph finite_state_machine {
        WaitingForInitialization ->InitiateContact [label = "InitializationCompleteReceived"];
        InitiateContact -> WaitingForContact [label = "ConsoleMonitorRequestContactSent"];
        WaitingForContact -> WaitingForContactTimeoutFailure [label = "ConsoleMonitorRequestContactSent"];
        WaitingForContact -> Contacted [label = "ConsoleMonitorRequestContactAcknowledgementReceived"];
        Contacted -> Connected [label = SubscribeToConsoleMonitorReceived];
        Connected -> Execute [label = "inputline == 1"];
        Connected -> Relinquish [label = "inputline == 99"]
        Connected -> Editing [label = "inputline == 2"];
        Editing -> Connected [label="editing complete"];
        Execute -> Connected [label = "LongRunningTaskStartedNotificationSent"];
        Relinquish -> Contacted [label = "RelinquishNotificationAcknowledgementReceived"];
        WaitingForInitialization ->ShuttingDown [label = "CancellationTokenActivated"];
        InitiateContact ->ShuttingDown [label = "CancellationTokenActivated"];
        WaitingForContact ->ShuttingDown [label = "CancellationTokenActivated"];
        WaitingForContactTimeoutFailure ->ShutdownStarted [label = "CancellationTokenActivated"];
        Contacted ->ShutdownStarted [label = "CancellationTokenActivated"];
        Connected ->ShutdownStarted [label = "CancellationTokenActivated"];
        Editing ->ShutdownStarted [label = "CancellationTokenActivated"];
        Execute ->ShutdownStarted [label = "CancellationTokenActivated"];
        Relinquish ->ShutdownStarted [label = "CancellationTokenActivated"];
        ShutdownStarted->ShutDownComplete [label = "AllShutDownStepsCompleted"];
        }
       */
      // By Convention add a method to the non-base compilationunit/ non-base primary class
      // StateMachine Configuration
      var gBody = new GBody(new List<string>() {
          "// attribution :https://github.com/dhrobbins/ApprovaFlow/blob/master/ApprovaFlow/ApprovaFlow/ApprovaFlow/Workflow/WorkflowProcessor.cs",
          "//  Get a distinct list of states with a trigger from the stateConfigurations static variable",
          "//  State => Trigger => TargetState",
          "var states = stateConfigurations.AsQueryable()",
          ".Select(x => x.State)",
          ".Distinct()",
          ".Select(x => x)",
          ".ToList();",
          "//  Get each trigger for each state",
          "states.ForEach(state =>{",
          "var triggers = stateConfigurations.AsQueryable()",
          ".Where(config => config.State == state)",
          ".Select(config => new { Trigger = config.Trigger, TargeState = config.TargetState })",
          ".ToList();",
          "triggers.ForEach(trig => {",
          "StateMachine.Configure(state).Permit(trig.Trigger, trig.TargeState);",
          "});",

        });
      var gMethodDeclaration = new GMethodDeclaration(gName: "ConfigureState", gType: "void", gAccessModifier: "override");
      var gMethod = new GMethod(gMethodDeclaration, gBody);
      // ToDo: Look up the right class via the Database
      GClass rightGClass = default;
      foreach (var gAU in gAssemblyGroup.GAssemblyUnits) {
        foreach (var gCU in gAU.Value.GCompilationUnits) {
          foreach (var gNs in gCU.Value.GNamespaces) {
            foreach (var gCl in gNs.Value.GClasss) {
              if (gCl.Value.GName == gAssemblyGroupName) {
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
      else {
        rightGClass?.GMethods.Add(gMethod.Philote, gMethod);
      }
      #endregion

      return gAssemblyGroup;
    }
  }
}
