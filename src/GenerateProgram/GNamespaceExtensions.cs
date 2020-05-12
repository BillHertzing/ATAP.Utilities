using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using GenerateProgram;
using static GenerateProgram.GAttributeGroupExtensions;

namespace GenerateProgram {
  public static partial class GNamespaceExtensions {

    public static GNamespace AddDelegate(this GNamespace gNamespace, GDelegate gDelegate) {
      gNamespace.GDelegates[gDelegate.Philote] = (gDelegate);
      return gNamespace;
    }
    public static GNamespace AddDelegate(this GNamespace gNamespace, IEnumerable<GDelegate> gDelegates) {
      foreach (var o in gDelegates) {
        gNamespace.GDelegates[o.Philote] = o;
      }
      return gNamespace;
    }
    public static GNamespace AddDelegate(this GNamespace gNamespace, Dictionary<Philote<GDelegate>,GDelegate> gDelegates) {
      foreach (var kvp in gDelegates) {
        gNamespace.AddDelegate(kvp.Value);
      }
      return gNamespace;
    }
    public static GNamespace AddDelegateGroups(this GNamespace gNamespace, GDelegateGroup gDelegateGroup) {
      gNamespace.GDelegateGroups[gDelegateGroup.Philote] = gDelegateGroup;
      return gNamespace;
    }
    public static GNamespace AddDelegateGroups(this GNamespace gNamespace, IEnumerable<GDelegateGroup> gDelegateGroups) {
      foreach (var o in gDelegateGroups) {
        gNamespace.GDelegateGroups[o.Philote] = o;
      }
      return gNamespace;
    }
    public static GNamespace AddDelegateGroup(this GNamespace gNamespace, IEnumerable<GDelegateGroup> gDelegateGroups) {
      foreach (var o in gDelegateGroups) {
        gNamespace.GDelegateGroups[o.Philote] = o;
      }
      return gNamespace;
    }
    public static GNamespace AddEnumeration(this GNamespace gNamespace, GEnumeration gEnumeration) {
      gNamespace.GEnumerations[gEnumeration.Philote] = (gEnumeration);
      return gNamespace;
    }
    public static GNamespace AddEnumeration(this GNamespace gNamespace, IEnumerable<GEnumeration> gEnumerations) {
      foreach (var o in gEnumerations) {
        gNamespace.GEnumerations[o.Philote] = o;
      }
      return gNamespace;
    }
    public static GNamespace AddEnumeration(this GNamespace gNamespace, Dictionary<Philote<GEnumeration>,GEnumeration> gEnumerations) {
      foreach (var kvp in gEnumerations) {
        gNamespace.AddEnumeration(kvp.Value);
      }
      return gNamespace;
    }
    public static GNamespace AddEnumerationGroup(this GNamespace gNamespace, GEnumerationGroup gEnumerationGroup) {
      gNamespace.GEnumerationGroups[gEnumerationGroup.Philote] = gEnumerationGroup;
      return gNamespace;
    }
    public static GNamespace AddEnumerationGroup(this GNamespace gNamespace, IEnumerable<GEnumerationGroup> gEnumerationGroups) {
      foreach (var o in gEnumerationGroups) {
        gNamespace.GEnumerationGroups[o.Philote] = o;
      }
      return gNamespace;
    }
    public static GNamespace AddEnumeration(this GNamespace gNamespace, Dictionary<Philote<GEnumerationGroup>,GEnumerationGroup> gEnumerationGroups) {
      foreach (var kvp in gEnumerationGroups) {
        gNamespace.AddEnumerationGroup(kvp.Value);
      }
      return gNamespace;
    }

 public static GNamespace CreateStateMachineDelegatesAndEnumerations(this GNamespace gNamespace) {
      //var gPropertys = new Dictionary<Philote<GProperty>, GProperty>();
      //foreach (var o in new List<GProperty>() {
      //  new GProperty(gName: "StateMachine", gType: "IStateMachine", gVisibility: "internal"),
      //}) {
      //  gPropertys[o.Philote] = o;
      //}
      var gDelegates = new Dictionary<Philote<GDelegate>, GDelegate>();
      var UnhandledTriggerDelegateArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in new List<GArgument>() {new GArgument("state", "State"), new GArgument("trigger", "Trigger"),}) {
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

      List<GEnumerationMember> gEnumerationMemberList = new List<GEnumerationMember>();
      Dictionary<Philote<GAttributeGroup>, GAttributeGroup> gAttributeGroups =
        new Dictionary<Philote<GAttributeGroup>, GAttributeGroup>();

      //gDescription: "Signals that the Console Monitor has received our request to be added",
      //gVisualDisplay: "Console Monitor Request Contact Acknowledgement Received",gVisibleSortOrder: 1
      GAttributeGroup gAttributeGroup = CreateLocalizableEnumerationAttributeGroup();
      gAttributeGroups[gAttributeGroup.Philote] = gAttributeGroup;
      gEnumerationMemberList.Add(
        new GEnumerationMember(gName: "ConsoleMonitorRequestContactAcknowledgementReceived", gValue: 1,
          gAttributeGroups: gAttributeGroups
        ));

      gAttributeGroups =  new Dictionary<Philote<GAttributeGroup>, GAttributeGroup>();
      //gDescription: "The Console Monitor is signaling us to subscribe to the ConsoleIn Observable",
      //gVisualDisplay: "Subscribe ToConsole Monitor Received", gVisibleSortOrder: 2),
      gAttributeGroup = CreateLocalizableEnumerationAttributeGroup();
      gAttributeGroups[gAttributeGroup.Philote] = gAttributeGroup;
      gEnumerationMemberList.Add( new GEnumerationMember(gName: "SubscribeToConsoleMonitorReceived", gValue: 2,
          gAttributeGroups: gAttributeGroups
      ));

      var gEnumerationMembers = new Dictionary<Philote<GEnumerationMember>, GEnumerationMember>();
      foreach (var o in gEnumerationMemberList) {
        gEnumerationMembers[o.Philote] = o;
      }

      var gEnumeration =
        new GEnumeration(gName: "Trigger", gVisibility: "public", gInheritance: "ATAP.Utilities.Enumerations",gEnumerationMembers: gEnumerationMembers);
      var gEnumerations = new Dictionary<Philote<GEnumeration>, GEnumeration>();
      gEnumerations[gEnumeration.Philote] = gEnumeration;
      gNamespace.AddDelegate(gDelegates);
      gNamespace.AddEnumeration(gEnumerations);
      return gNamespace;
      
    }
 public static GNamespace CreateStateMachineInitialization(this GNamespace gNamespace, Philote<GClass> gClassID, Philote<GMethod> gMethodID) {
   //var gPropertys = new Dictionary<Philote<GProperty>, GProperty>();
   //foreach (var o in new List<GProperty>() {
   //  new GProperty(gName: "StateMachine", gType: "IStateMachine", gVisibility: "internal"),
   //}) {
   //  gPropertys[o.Philote] = o;
   //}
   // This is the class and the constructor in which to Initialize the statemachine
   GClass gClass = gNamespace.GClasss[gClassID];
   // Find the method by its Philote value
   var gMethod = gClass.GConstructors[gMethodID];
   // Add the StateMachine Property to the class
   var gProperty = new GProperty(gName: "StateMachine", gAccessors: "{get;}");
   // Add the StateMachine Property initializtion to the constructor body
   var gBody = gMethod.GBody;
   var gAdditionalStatements = new List<String>(){"StateMachine<State, Trigger> = new StateMachine<State, Trigger>(State,Trigger);"};
   gBody.GStatements.AddRange(gAdditionalStatements);
   return gNamespace;
 }
    }
}
