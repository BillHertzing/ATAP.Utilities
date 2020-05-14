using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyGroupExtensions;
//using AutoMapper.Configuration;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GUsingGroupExtensions;
using static GenerateProgram.GAttributeGroupExtensions;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblyGroup MFileSystemToObjectGraph(
      string subDirectoryForGeneratedFiles = default, string baseNamespace = default
    ) {
      var gAssemblyGroupName = "FilesystemToObjectGraphGHService";

      var gAssemblyGroup =
        GAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespace);

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
        WaitingForInitialization ->InitiateContactWithConsoleMonitor [label = "InitializationCompleteReceived"];
        InitiateContactWithConsoleMonitor -> WaitingForContact [label = "ConsoleMonitorRequestContactSent"];
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
      gAttributeGroup = CreateLocalizableEnumerationAttributeGroup(description: "Sent a ContactRequest to the ConsoleMonitor", visualDisplay: "Console Monitor RequestContact Sent", visualSortOrder: 2);
      gAttributeGroups[gAttributeGroup.Philote] = gAttributeGroup;
      gEnumerationMemberList.Add(new GEnumerationMember(gName: "ConsoleMonitorRequestContactSent", gValue: 2, gAttributeGroups: gAttributeGroups));

      var gEnumerationMembers = new Dictionary<Philote<GEnumerationMember>, GEnumerationMember>();
      foreach (var o in gEnumerationMemberList) {
        gEnumerationMembers[o.Philote] = o;
      }
      #endregion
      var gEnumeration =
        new GEnumeration(gName: "State", gVisibility: "public", gInheritance: "",
          gEnumerationMembers: gEnumerationMembers);
      gEnumerationGroup.GEnumerations[gEnumeration.Philote] = gEnumeration;
      #endregion
      #region Trigger Enumeration
      #region Trigger Enumeration members
      gEnumerationMemberList = new List<GEnumerationMember>();
      gAttributeGroups = new Dictionary<Philote<GAttributeGroup>, GAttributeGroup>();
      gAttributeGroup = CreateLocalizableEnumerationAttributeGroup(description: "The minimal initialization conditions have been met",visualDisplay: "Initialization Complete Received",visualSortOrder: 2);
      gAttributeGroups[gAttributeGroup.Philote] = gAttributeGroup;
      gEnumerationMemberList.Add(new GEnumerationMember(gName: "InitializationCompleteReceived", gValue: 1, gAttributeGroups: gAttributeGroups));
      gAttributeGroups = new Dictionary<Philote<GAttributeGroup>, GAttributeGroup>();
      gAttributeGroup = CreateLocalizableEnumerationAttributeGroup(description: "Sent a ContactRequest to the ConsoleMonitor",visualDisplay: "Console Monitor RequestContact Sent",visualSortOrder: 2);
      gAttributeGroups[gAttributeGroup.Philote] = gAttributeGroup;
      gEnumerationMemberList.Add(new GEnumerationMember(gName: "ConsoleMonitorRequestContactSent", gValue: 1, gAttributeGroups: gAttributeGroups));

      gEnumerationMembers = new Dictionary<Philote<GEnumerationMember>, GEnumerationMember>();
      foreach (var o in gEnumerationMemberList) {
        gEnumerationMembers[o.Philote] = o;
      }
      #endregion
      gEnumeration =
        new GEnumeration(gName: "Trigger", gVisibility: "public", gInheritance: "",
          gEnumerationMembers: gEnumerationMembers);
      gEnumerationGroup.GEnumerations[gEnumeration.Philote] = gEnumeration;
      #endregion
      gNamespace.AddEnumerationGroup(gEnumerationGroup);

      #endregion
      #region StateMachine Transitions
      // Add a StaticVariable to the class
      var gStaticVariable = new GStaticVariable("stateConfigurations", gType: "List<StateConfiguration>",
        gBody: new GBody(new List<string>() {
          "new List<StateConfiguration>(){",
          "new StateConfiguration(State.WaitingForInitialization,Trigger.InitializationCompleteReceived,State.InitiateContactWithConsoleMonitor),",
          "}"
        }));
      gClass.GStaticVariables.Add(gStaticVariable.Philote, gStaticVariable);

      #endregion
      #endregion
      #region Use MConsoleMonitorClient to implement the  GHConsoleMonitorServicePattern
      MConsoleMonitorClient(gAssemblyGroup, baseNamespace);
      #endregion
      #region Specific to FilesystemToObjectGraph
            #region Base Assembly Unit
      // Get the namespace, and class, to which the gEnumerationGroup and GStaticVariable will be added
      GAssemblyUnit gAssemblyUnit = default;
      GCompilationUnit gCompilationUnit = default;
      gNamespace = default;
      gClass = default;
      GMethod gConstructor = default;
      // ToDo: Look up the right class via the Database
      foreach (var gAU in gAssemblyGroup.GAssemblyUnits) {
        foreach (var gCU in gAU.Value.GCompilationUnits) {
          foreach (var gNs in gCU.Value.GNamespaces) {
            foreach (var gCl in gNs.Value.GClasss) {
              if (gCl.Value.GName == "AssemblyUnitNameReplacementPatternBase") {
                foreach (var gMe in gCl.Value.GConstructors) {
                  //foreach (var gMe in gCl.Value.CombinedMethods()) {
                  if (gMe.Value.GDeclaration.IsConstructor) {
                    gAssemblyUnit = gAU.Value;
                    gCompilationUnit = gCU.Value;
                    gNamespace = gNs.Value;
                    gClass = gCl.Value;
                    gConstructor = gMe.Value;
                    // ToDo: break out to the outermost loop
                  }
                }
              }
            }
          }
        }
      }
      if (gClass == default) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      MFilesystemToObjectGraphBaseAssembly(gAssemblyUnit, gCompilationUnit, gNamespace, gClass, gConstructor, baseNamespace);
      #endregion
      #region Interface Assembly Unit
      GInterface gInterface = default;
      // ToDo: Look up the right class via the Database
      foreach (var gAU in gAssemblyGroup.GAssemblyUnits) {
        foreach (var gCU in gAU.Value.GCompilationUnits) {
          if (gCU.Value.GName == "AssemblyUnitNameReplacementPatternBase.Interfaces") {
            foreach (var gNs in gCU.Value.GNamespaces) {
              foreach (var gIn in gNs.Value.GInterfaces) {
                if (gIn.Value.GName == "AssemblyUnitNameReplacementPattern") {
                }

                gAssemblyUnit = gAU.Value;
                gCompilationUnit = gCU.Value;
                gNamespace = gNs.Value;
                gInterface = gIn.Value;
                // ToDo: break out to the outermost loop
              }
            }
          }
        }
      }
      if (gInterface == default) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      MFilesystemToObjectGraphInterfaceAssembly(gAssemblyUnit, gCompilationUnit, gNamespace, gInterface, baseNamespace);
      #endregion
      #endregion
      return gAssemblyGroup;
    }
    public static void MFilesystemToObjectGraphBaseAssembly(GAssemblyUnit gAssemblyUnit, GCompilationUnit gCompilationUnit,
         GNamespace gNamespace, GClass gClass, GMethod gConstructor, string baseNamespace) {
      #region Base Asembly Unit
      #region UsingGroup
      MUsingsForFilesystemToObjectGraphBaseAssembly(gCompilationUnit, baseNamespace);
      #endregion
      #region PropertyGroup
      MPropertyGroupForFilesystemToObjectGraphBaseAssembly(gClass);
      #endregion
      #region Injected PropertyGroup
      MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedPropertyInFilesystemToObjectGraphBaseAssembly(gClass, gConstructor);
      #endregion
      #region MethodGroup
      MMethodGroupForFilesystemToObjectGraphBaseAssembly(gClass);
      #endregion
      #region ItemGroups for the ProjectUnit
      MProjectReferenceItemGroupInProjectUnitForFilesystemToObjectGraphBaseAssembly(gAssemblyUnit);
      #endregion
      #endregion
    }
    public static void MFilesystemToObjectGraphInterfaceAssembly(GAssemblyUnit gAssemblyUnit, GCompilationUnit gCompilationUnit,
        GNamespace gNamespace, GInterface gInterface, string baseNamespace) {
      #region Interface Assembly Unit
      #region UsingGroup
      MUsingsForFilesystemToObjectGraphInterfaceAssembly(gCompilationUnit, baseNamespace);
      #endregion
      #region PropertyGroup 
      MPropertyGroupForFilesystemToObjectGraphInterfaceAssembly(gInterface);
      #endregion
      //#region Injected PropertyGroup 
      //MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedPropertyInFilesystemToObjectGraphInterfaceAssembly(gInterface, gConstructor);
      //#endregion
      #region MethodGroup 
      MMethodGroupForFilesystemToObjectGraphInterfaceAssembly(gInterface);
      #endregion
      #region ReferenceItemGroups for the ProjectUnit
      MProjectReferenceItemGroupInProjectUnitForFilesystemToObjectGraphInterfaceAssembly(gAssemblyUnit);
      #endregion
      #endregion
    }

    public static void MUsingsForFilesystemToObjectGraphBaseAssembly(GCompilationUnit gCompilationUnit, string baseNamespace) {
      var gUsingGroup = new GUsingGroup("Usings For ConsoleMonitor Pattern").AddUsing(new List<GUsing>() {
        new GUsing($"{baseNamespace}.ConsoleMonitor"),
      });
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
    }
    public static void MPropertyGroupForFilesystemToObjectGraphBaseAssembly(GClass gClass) {
      var gPropertyGroup = new GPropertyGroup("Propertys specific to the FilesystemToObjectGraph");
      foreach (var o in new List<GProperty>() {
        // new GProperty("?", gType: "IDisposable",gAccessors: "{ get; set; }", gVisibility: "protected internal"),
        // new GProperty("Choices", gType: "Dictionary<String,IEnumerable<string>>", gAccessors: "{ get; }", gVisibility: "protected internal"),
      }) {
        gPropertyGroup.GPropertys[o.Philote] = o;
      }
      gClass.AddPropertyGroups(gPropertyGroup);
    }
    public static void MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedPropertyInFilesystemToObjectGraphBaseAssembly(GClass gClass,
      GMethod gConstructor) {
      var gPropertyGroup = new GPropertyGroup("Injected Propertys specific to the FilesystemToObjectGraph");
      gClass.AddPropertyGroups(gPropertyGroup);
      // foreach (var o in new List<string>() { "ConsoleMonitor" }) {
      // gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, o, gPropertyGroupId: gPropertyGroup.Philote);
      // }
    }
    public static void MMethodGroupForFilesystemToObjectGraphBaseAssembly(GClass gClass) {
      var gMethodGroup =
        new GMethodGroup(gName: "MethodGroup specific to the FilesystemToObjectGraph");
      // GMethod gMethod = CreateWriteAsyncMethod();
      // gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      // gMethod = MBuildMenuMethodForConsoleMonitorPatter();
      // gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      //gMethod = new GMethod().CreateReadCharMethod();
      //newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gClass.AddMethodGroup(gMethodGroup);
    }
    public static void
      MProjectReferenceItemGroupInProjectUnitForFilesystemToObjectGraphBaseAssembly(GAssemblyUnit gAssemblyUnit) {

      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ReferencesUsedByFilesystemToObjectGraph",
        "References used by the FilesystemToObjectGraph", new GBody(new List<string>() {
          "<PackageReference Include=\"ATAP.Utilities.ComputerInventory.Hardware\" />",
          "<PackageReference Include=\"ATAP.Utilities.Persistence\" />",
        }));
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gItemGroupInProjectUnit.Philote,
        gItemGroupInProjectUnit);
    }
    public static void MUsingsForFilesystemToObjectGraphInterfaceAssembly(GCompilationUnit gCompilationUnit, string baseNamespace) {
      var gUsingGroup = new GUsingGroup("Usings For ConsoleMonitor Pattern").AddUsing(new List<GUsing>() {
        new GUsing($"{baseNamespace}.ConsoleMonitor"),
      });
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
    }
    public static void MPropertyGroupForFilesystemToObjectGraphInterfaceAssembly(GInterface gInterface) {
      var gPropertyGroup = new GPropertyGroup("Propertys specific to the FilesystemToObjectGraph");
      foreach (var o in new List<GProperty>() {
        // new GProperty("?", gType: "IDisposable",gAccessors: "{ get; set; }", gVisibility: "protected internal"),
        // new GProperty("Choices", gType: "Dictionary<String,IEnumerable<string>>", gAccessors: "{ get; }", gVisibility: "protected internal"),
      }) {
        gPropertyGroup.GPropertys[o.Philote] = o;
      }
      gInterface.AddPropertyGroups(gPropertyGroup);
    }
    public static void MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedPropertyInFilesystemToObjectGraphInterfaceAssembly(GInterface gInterface,
      GMethod gConstructor) {
      var gPropertyGroup = new GPropertyGroup("Injected Propertys specific to the FilesystemToObjectGraph");
      gInterface.AddPropertyGroups(gPropertyGroup);
      // foreach (var o in new List<string>() { "ConsoleMonitor" }) {
      // gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, o, gPropertyGroupId: gPropertyGroup.Philote);
      // }
    }
    public static void MMethodGroupForFilesystemToObjectGraphInterfaceAssembly(GInterface gInterface) {
      var gMethodGroup =
        new GMethodGroup(gName: "MethodGroup specific to the FilesystemToObjectGraph");
      // GMethod gMethod = CreateWriteAsyncMethod();
      // gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      // gMethod = MBuildMenuMethodForConsoleMonitorPatter();
      // gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      //gMethod = new GMethod().CreateReadCharMethod();
      //newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gInterface.AddMethodGroup(gMethodGroup);
    }
    public static void
      MProjectReferenceItemGroupInProjectUnitForFilesystemToObjectGraphInterfaceAssembly(GAssemblyUnit gAssemblyUnit) {

      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ReferencesUsedByFilesystemToObjectGraph.Interface",
        "References used by the FilesystemToObjectGraph Interface", new GBody(new List<string>() {
          "<PackageReference Include=\"ATAP.Utilities.Persistence.Interfaces\" />",
        }));
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gItemGroupInProjectUnit.Philote,
        gItemGroupInProjectUnit);
    }
  }
}
