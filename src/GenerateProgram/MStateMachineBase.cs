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
    public static void MStateMachineBase(
      GCompilationUnit gCompilationUnit = default, GNamespace gNamespace = default, GClass gClass = default, GMethod gConstructor = default) {
      #region UsingGroup
      var gUsingGroup = UsingGroupForStatelessStateMachine();
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      #endregion
      #region Delegates
      var gDelegates = new Dictionary<Philote<GDelegate>, GDelegate>();
      var UnhandledTriggerDelegateArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in new List<GArgument>() { new GArgument("state", "State"), new GArgument("trigger", "Trigger"), }) {
        UnhandledTriggerDelegateArguments[o.Philote] = o;
      }
      foreach (var o in new List<GDelegate>() {
        new GDelegate(new GDelegateDeclaration("UnHandledTriggerDelegate", gType: "void", gVisibility: "public",
          gArguments: UnhandledTriggerDelegateArguments)),
        new GDelegate(new GDelegateDeclaration(gName: "EntryExitDelegate", gType: "void", gVisibility: "public")),
        new GDelegate(new GDelegateDeclaration(gName: "GuardClauseDelegate", gType: "void", gVisibility: "public")),
      }) {
        gDelegates[o.Philote] = o;
      }
      gNamespace.AddDelegate(gDelegates);

      #endregion

      // Property Group for StateMachine properties
      var gPropertyGroup = new GPropertyGroup(gName: "StateMachine Properties");
      // StateConfigurations Property
      var gProperty = new GProperty(gName: "StateMachine", gType: "StateMachine<State,Trigger>", gAccessors: "{get;}");
      gPropertyGroup.GPropertys.Add(gProperty.Philote, gProperty);
      // Add the StateMachine Property to the class
      gProperty = new GProperty(gName: "StateConfigurations", gType: "List<StateConfiguration>", gAccessors: "{get;}");
      gPropertyGroup.GPropertys.Add(gProperty.Philote, gProperty);
      gClass.GPropertyGroups.Add(gPropertyGroup.Philote,gPropertyGroup);
      // add a method to the class that configures the StateMachine according to the StateConfigurations property
      // StateMachine Configuration

      var gMethodGroup = new GMethodGroup(gName:"Methods For StateMachine");

      var gMethod = new GMethod(new GMethodDeclaration(gName: "ConfigureStateMachine", gType: "void",gVisibility:"public", gAccessModifier: "virtual"), new GBody(new List<string>() {
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
          ".Select(config => new { Trigger = config.Trigger, TargetState = config.NextState })",
          ".ToList();",
          "triggers.ForEach(trig => {",
          "StateMachine.Configure(state).Permit(trig.Trigger, trig.TargetState);",
        "  });",
        "});",
      }));
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      gClass.GMethodGroups.Add(gMethodGroup.Philote, gMethodGroup);

      // Add initialization statements for the properties in the the StateMachine Properties Property Group to the constructor body
      gConstructor.GBody.GStatements.AddRange(new List<String>() {
        "StateMachine = new StateMachine<State, Trigger>(State.WaitingForInitialization);",
        "StateConfigurations = stateConfigurations;",
        "ConfigureStateMachine();",
      });

      // StateConfiguration Class for the provided namespace
      // Define the properties for the StateConfiguration class
      // ToDo: Move this type into ATAP.Utilities.StateMachine
      var gPropertys = new Dictionary<Philote<GProperty>, GProperty>();
       gProperty = new GProperty("State", "State", gAccessors: "{get;}", gVisibility:"public");
      gPropertys.Add(gProperty.Philote, gProperty);
      gProperty = new GProperty("Trigger", "Trigger", gAccessors: "{get;}", gVisibility:"public");
      gPropertys.Add(gProperty.Philote, gProperty);
      gProperty = new GProperty("NextState", "State", gAccessors: "{get;}", gVisibility:"public");
      gPropertys.Add(gProperty.Philote, gProperty);
      var stateConfigurationClass = new GClass(gName: "StateConfiguration", gPropertys: gPropertys);

      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in new List<GArgument>() {
        new GArgument("state","State"),
        new GArgument("trigger","Trigger"),
        new GArgument("nextState","State"),
      }) { gMethodArguments.Add(o.Philote, o); }

      gConstructor= new GMethod(
        new GMethodDeclaration(gName:"StateConfiguration",isConstructor:true, gType: "IDisposable",
          gVisibility: "public", gAccessModifier: "", 
          gArguments: gMethodArguments),
        gBody:
        new GBody( new List<string>() {
          "State=state;",
          "Trigger=trigger;",
          "NextState=nextState;",
        }),
        new GComment(new List<string>() {
          "/// <summary>",
          "/// builds one state instance",
          "/// </summary>",
          "/// <returns></returns>",

        }));
      stateConfigurationClass.GConstructors.Add(gConstructor.Philote, gConstructor);
      gNamespace.GClasss.Add(stateConfigurationClass.Philote, stateConfigurationClass);

    }
  }
}
