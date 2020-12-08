using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using ATAP.Utilities.Philote;
//using AutoMapper.Configuration;
using static GenerateProgram.GUsingGroupExtensions;
using static GenerateProgram.GEnumerationMemberExtensions;
using System;
using System.Text;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static void MStateMachineConstructor(
      GCompilationUnit gCompilationUnit = default, GNamespace gNamespace = default, GClass gClass = default,
      GMethod gConstructor = default, List<string> initialDiGraphList = default) {
      #region UsingGroup
      var gUsingGroup = MUsingGroupForStatelessStateMachine();
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Delegates
      var gDelegates = new Dictionary<Philote<GDelegate>, GDelegate>();
      var UnhandledTriggerDelegateArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in new List<GArgument>() {new GArgument("state", "State"), new GArgument("trigger", "Trigger"),}) {
        UnhandledTriggerDelegateArguments.Add(o.Philote, o);
      }
      foreach (var o in new List<GDelegate>() {
        new GDelegate(new GDelegateDeclaration("UnHandledTriggerDelegate", gType: "void", gVisibility: "public",
          gArguments: UnhandledTriggerDelegateArguments)),
        new GDelegate(new GDelegateDeclaration(gName: "EntryExitDelegate", gType: "void", gVisibility: "public")),
        new GDelegate(new GDelegateDeclaration(gName: "GuardClauseDelegate", gType: "void", gVisibility: "public")),
      }) {
        gDelegates.Add(o.Philote, o);
      }
      gNamespace.AddDelegate(gDelegates);
      #endregion

      #region StateMachine GPropertyGroup and its porperties
      var gPropertyGroup = new GPropertyGroup(gName: "StateMachine Properties");
      // StateMachine Property
      var gProperty = new GProperty(gName: "StateMachine", gType: "StateMachine<State,Trigger>", gAccessors: "{get;}");
      gPropertyGroup.GPropertys.Add(gProperty.Philote, gProperty);
      // StateConfigurations property
      //gProperty = new GProperty(gName: "StateConfigurations", gType: "List<StateConfiguration>", gAccessors: "{get;}");
      //gPropertyGroup.GPropertys.Add(gProperty.Philote, gProperty);
      // Add the PropertyGroup to the gClass
      gClass.GPropertyGroups.Add(gPropertyGroup.Philote, gPropertyGroup);
      #endregion

      // Add initialization statements for the properties in the the StateMachine Properties Property Group to the constructor body
      gConstructor.GBody.GStatements.AddRange(new List<string>() {
        "StateMachine = new StateMachine<State, Trigger>(State.WaitingForInitialization);",
        "//StateConfigurations = stateConfigurations;",
        "ConfigureStateMachine();",
      });

      //// StateConfiguration Class for the provided namespace
      //// Define the properties for the StateConfiguration class
      //// ToDo: Move this type into ATAP.Utilities.StateMachine
      //var gPropertys = new Dictionary<Philote<GProperty>, GProperty>();
      //gProperty = new GProperty("State", "State", gAccessors: "{get;}", gVisibility: "public");
      //gPropertys.Add(gProperty.Philote, gProperty);
      //gProperty = new GProperty("Trigger", "Trigger", gAccessors: "{get;}", gVisibility: "public");
      //gPropertys.Add(gProperty.Philote, gProperty);
      //gProperty = new GProperty("NextState", "State", gAccessors: "{get;}", gVisibility: "public");
      //gPropertys.Add(gProperty.Philote, gProperty);
      //var stateConfigurationClass = new GClass(gName: "StateConfiguration", gPropertys: gPropertys);

      //var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      //foreach (var o in new List<GArgument>() {
      //  new GArgument("state", "State"), new GArgument("trigger", "Trigger"), new GArgument("nextState", "State"),
      //}) {
      //  gMethodArguments.Add(o.Philote, o);
      //}

      //gConstructor = new GMethod(
      //  new GMethodDeclaration(gName: "StateConfiguration", isConstructor: true, gType: "IDisposable",
      //    gVisibility: "public", gAccessModifier: "",
      //    gArguments: gMethodArguments),
      //  gBody:
      //  new GBody(new List<string>() {"State=state;", "Trigger=trigger;", "NextState=nextState;",}),
      //  new GComment(new List<string>() {
      //    "/// <summary>", "/// builds one state instance", "/// </summary>", "/// <returns></returns>",
      //  }));
      //stateConfigurationClass.GMethods.Add(gConstructor.Philote, gConstructor);
      //gNamespace.GClasss.Add(stateConfigurationClass.Philote, stateConfigurationClass);
    }
    public static void ParseDiGraphToStateMachine(GStateConfiguration gStateConfiguration = default) {
      const string pattern = @"\s*(?<State>.+?)\s*->\s*(?<NextState>.+?)\s*\[label\s*=\s*""(?<Trigger>[^""\]]+?)""\]";
      Regex regex = new Regex(pattern);
      //StringBuilder diGraphSB = new StringBuilder();
      //diGraph.ForEach(sc => {
      //    sc.GStateTransitions.ForEach(st => {
      //        diGraphSB.Append(st);
      //    });
      //});

      var diGraphStates = regex.Matches(string.Join(" ", gStateConfiguration.GDOTGraphStatements)).Cast<Match>()
        .Select(x => (State: x.Groups["State"].Value, Trigger: x.Groups["Trigger"].Value,
          NextState: x.Groups["NextState"].Value, GuardPredicate: x.Groups["GuardPredicate"].Value));
      //var stateNames = diGraphStates.Select(x => x.State).Concat(diGraphStates.Select(x => x.NextState)).Distinct();
      //var triggerNames = diGraphStates.Select(x => x.Trigger).Distinct();
      //var transitionNames = diGraphStates.Select(x => (fromState: x.State,toState: x.NextState, trigger:x.Trigger).Distinct();
      var stateConfigurations = diGraphStates.Select(x =>
        $"new StateConfiguration(state:State.{x.State},trigger:Trigger.{x.Trigger},nextState:State.{x.NextState}),");
      gStateConfiguration.GDiGraphStates.AddRange(diGraphStates);
      gStateConfiguration.GStateNames.AddRange( diGraphStates.Select(x => x.State).Concat(diGraphStates.Select(x => x.NextState)).Distinct());
      gStateConfiguration.GTriggerNames.AddRange( diGraphStates.Select(x => x.Trigger).Distinct());

      //return (stateNames, triggerNames, stateConfigurations);
    }
    //public static void MStateMachineFinalizer(
    //  (
    //    IEnumerable<GAssemblyUnit> gAssemblyUnits,
    //    IEnumerable<GCompilationUnit> gCompilationUnits,
    //    IEnumerable<GNamespace> gNamespacess,
    //    IEnumerable<GClass> gClasss,
    //    IEnumerable<GMethod> gMethods) lookupResults) {

    //  MStateMachineFinalizer(lookupResults.gCompilationUnits.First(), lookupResults.gNamespacess.First(),
    //    lookupResults.gClasss.First(), lookupResults.gMethods.First(), finalGStateConfigurations);
    //}
    //public static void MStateMachineFinalizer() {
    //  MStateMachineFinalizer(mCreateAssemblyGroupResult.gTitularBaseCompilationUnit,
    //    mCreateAssemblyGroupResult.gNamespaceBase, mCreateAssemblyGroupResult.gClassBase,
    //    gStateConfiguration: mCreateAssemblyGroupResult.gPrimaryConstructorBase.GStateConfigurations);
    //}
    public static void MStateMachineFinalizer(GAssemblyGroupBasicConstructorResult mCreateAssemblyGroupResult) {
      #region Accumulate the StateConfigurations
      var finalGStateConfiguration = new GStateConfiguration();
      foreach (var gAU in mCreateAssemblyGroupResult.gAssemblyGroup.GAssemblyUnits) {
        // finalGStateConfigurations.Add(gAu.GStateConfiguration);
        foreach (var gCU in gAU.Value.GCompilationUnits) {
          // finalGStateConfigurations.Add(gCu.GStateConfiguration);
          foreach (var gNs in gCU.Value.GNamespaces) {
            // finalGStateConfigurations.Add(gNs.GStateConfiguration);
            foreach (var gCl in gNs.Value.GClasss) {
              // finalGStateConfigurations.Add(gCl.GStateConfiguration);
              foreach (var gMe in gCl.Value.CombinedMethods()) {
                finalGStateConfiguration.GDOTGraphStatements.AddRange(gMe.GStateConfiguration.GDOTGraphStatements);
              }
            }
          }
        }
      }
      #endregion
      if (finalGStateConfiguration.GDOTGraphStatements.Any()) {
        //var parsedDiGraph = ParseDiGraphToStateMachine(finalGStateConfiguration);
        ParseDiGraphToStateMachine(finalGStateConfiguration);
        #region StateMachine EnumerationGroups
        var gEnumerationGroup = new GEnumerationGroup(gName: "State and Trigger Enumerations for StateMachine");
        #region State Enumeration
        #region State Enumeration members
        var gEnumerationMemberList = new List<GEnumerationMember>();
        var enumerationValue = 1;
        foreach (var name in finalGStateConfiguration.GStateNames) {
          gEnumerationMemberList.Add(LocalizableEnumerationMember(name, enumerationValue++));
        }
        // gEnumerationMemberList = new List<GEnumerationMember>() {
        //  LocalizableEnumerationMember("WaitingForInitialization",1,"Power-On State - waiting until minimal initialization condition has been met","Waiting For Initialization"),
        //  LocalizableEnumerationMember("InitiateContact",1,"Signal to the Console Monitor that we are a valid ConsoleSource","Initiate Contact"),
        //};
        var gEnumerationMembers = new Dictionary<Philote<GEnumerationMember>, GEnumerationMember>();
        foreach (var o in gEnumerationMemberList) {
          gEnumerationMembers.Add(o.Philote, o);
        }
        #endregion
        var gEnumeration = new GEnumeration(gName: "State", gVisibility: "public", gInheritance: "",
          gEnumerationMembers: gEnumerationMembers);
        #endregion
        gEnumerationGroup.GEnumerations.Add(gEnumeration.Philote, gEnumeration);
        #region Trigger Enumeration
        #region Trigger Enumeration members
        gEnumerationMemberList = new List<GEnumerationMember>();
        enumerationValue = 1;
        foreach (var name in finalGStateConfiguration.GTriggerNames) {
          gEnumerationMemberList.Add(LocalizableEnumerationMember(name, enumerationValue++));
        }
        //gEnumerationMemberList = new List<GEnumerationMember>() {
        //  LocalizableEnumerationMember("InitializationCompleteReceived",1,"The minimal initialization conditions have been met","Initialization Complete Received"),
        //};
        gEnumerationMembers =
          new Dictionary<Philote<GEnumerationMember>, GEnumerationMember
          >(); //{gEnumerationMemberList.ForEach(m=>m.Philote,m)};
        foreach (var o in gEnumerationMemberList) {
          gEnumerationMembers.Add(o.Philote, o);
        }
        #endregion
        gEnumeration =
          new GEnumeration(gName: "Trigger", gVisibility: "public", gInheritance: "",
            gEnumerationMembers: gEnumerationMembers);
        gEnumerationGroup.GEnumerations.Add(gEnumeration.Philote, gEnumeration);
        #endregion
        mCreateAssemblyGroupResult.gNamespaceBase.AddEnumerationGroup(gEnumerationGroup);
        #endregion

        //#region StateMachine Transitions Static variable
        //// Add a StaticVariable to the class
        //List<string> gStatements = new List<string>() {"new List<StateConfiguration>(){"};
        //foreach (var sc in parsedDiGraph.StateConfigurations) {
        //  gStatements.Add(sc);
        //}
        //gStatements.Add("}");
        //var gStaticVariable = new GStaticVariable("stateConfigurations", gType: "List<StateConfiguration>",
        //  gBody: new GBody(gStatements));
        //gClass.GStaticVariables.Add(gStaticVariable.Philote, gStaticVariable);
        //#endregion

        #region Create the detailed ConfigureStateMachine Method using the parsedDiGraph information
        // add a method to the class that configures the StateMachine according to the StateConfigurations parsed from the diGraph
        var gMethodGroup = new GMethodGroup(gName: "Detailed ConfigureStateMachine Method");
        var gBody = new GBody(new List<string>());
        var gMethod =
          new GMethod(
            new GMethodDeclaration(gName: "ConfigureStateMachine", gType: "void", gVisibility: "private",
              gAccessModifier: ""), gBody);
        //"// attribution :https://github.com/dhrobbins/ApprovaFlow/blob/master/ApprovaFlow/ApprovaFlow/ApprovaFlow/Workflow/WorkflowProcessor.cs",
        //"// attribution :https://github.com/frederiksen/Stateless-Designer/blob/master/src/StatelessDesigner.VS2017/StatelessCodeGenerator/StatelessCodeGenerator.cs",
        //"// Heavily modified to work in a code generator",
        //"",
        //gBody.GStatements.Add(
        // "#region Delegates for each state's Entry and Exit method calls, and GuardClauses method calls");
        foreach (var stateName in finalGStateConfiguration.GStateNames) {
          gBody.GStatements.Add($"StateMachine.Configure(State.{stateName})" );
          var permittedStateTransitions = finalGStateConfiguration.GDiGraphStates.Where(x => x.state == stateName)
            .Select(x => (triggerName: x.trigger, nextStateName: x.nextstate));
          foreach (var pST in permittedStateTransitions) {
            gBody.GStatements.Add($"  .Permit(Trigger.{pST.triggerName},State.{pST.nextStateName})" );
          }
          gBody.GStatements.Add($";" );
          //    $"public EntryExitDelegate On{stateName}Entry = null;",
          //    $"public EntryExitDelegate On{stateName}Exit = null;",
        };
        //}
        //gBody.GStatements.Add("#endregion");
//gBody.GStatements.Add("#region Fluent");
        //foreach (var stateConfiguration in parsedDiGraph.StateConfigurations) {
        //  //gBody.GStatements. Add("StateMachine.Configure($State},");
        //  //  if (true) // stateName == stateConfiguration) {
        //  //    gBody.GStatements.Add($"#endregion");
        //}
        // gBody.GStatements.Add("#endregion");

        //gBody.GStatements.AddRange(
        //  "#region Delegates for each state's Entry and Exit method calls, and GuardClauses method calls",
        //  "#endregion "
        //  );

        //"//  Get a distinct list of states with a trigger from the stateConfigurations static variable",
        //"//  State => Trigger => TargetState",
        //"var states = StateConfigurations.AsQueryable()",
        //".Select(x => x.State)",
        //".Distinct()",
        //".Select(x => x)",
        //".ToList();",
        //"//  Get each trigger for each state",
        //"states.ForEach(state =>{",
        //"var triggers = StateConfigurations.AsQueryable()",
        //".Where(config => config.State == state)",
        //".Select(config => new { Trigger = config.Trigger, TargetState = config.NextState })",
        //".ToList();",
        //"triggers.ForEach(trig => {",
        //"StateMachine.Configure(state).Permit(trig.Trigger, trig.TargetState);",
        //"  });",
        //"});",
        #endregion
        gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
        mCreateAssemblyGroupResult.gClassBase.GMethodGroups.Add(gMethodGroup.Philote, gMethodGroup);
        #region Add the statement that fires the InitializationCompleteReceived Trigger
        //var statementList = gClass.CombinedMethods().Where(x => x.GDeclaration.GName == "StartAsync").First().GBody
        //  .GStatements;
        //statementList.Insert(statementList.Count - 1, "StateMachine.Fire(Trigger.InitializationCompleteReceived);");
        #endregion
      }
    }
  }
}
