using System;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyUnitExtensions;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static GenerateProgram.Lookup;

//using AutoMapper.Configuration;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblyGroup MAUStateless(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default) {
      return MAUStateless(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, new GPatternReplacement());
    }
    public static GAssemblyGroup MAUStateless(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default ) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;

      
      var part1Tuple = MAssemblyGroupBasicConstructorPart1(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, _gPatternReplacement);
      var gAssemblyGroup = part1Tuple.gAssemblyGroup;
      var gTitularAssemblyUnit = part1Tuple.gTitularAssemblyUnit;
      var gCompilationUnitDerived = part1Tuple.gCompilationUnitDerived;
      var gCompilationUnitBase = part1Tuple.gCompilationUnitBase;
      var gNamespaceDerived = part1Tuple.gNamespaceDerived;
      var gNamespaceBase = part1Tuple.gNamespaceBase;
      var gClassDerived = part1Tuple.gClassDerived;
      var gClassBase = part1Tuple.gClassBase;
      var gPrimaryConstructorBase = part1Tuple.gPrimaryConstructorBase;
      var gTitularInterfaceAssemblyUnit = part1Tuple.gTitularInterfaceAssemblyUnit;
      var gTitularInterfaceDerivedCompilationUnit = part1Tuple.gTitularInterfaceDerivedCompilationUnit;
      var gTitularInterfaceBaseCompilationUnit = part1Tuple.gTitularInterfaceBaseCompilationUnit;
      var gTitularInterfaceDerivedInterface = part1Tuple.gTitularInterfaceDerivedInterface;
      var gTitularInterfaceBaseInterface = part1Tuple.gTitularInterfaceBaseInterface;

      //#region Select the Titular AssemblyUnit, Titular StateMachineDiGraph, TitularBase CompilationUnit, Namespace, Class, and Constructor
      //var titularBaseClassName = $"{gAssemblyGroupName}Base";
      //var titularClassName = $"{gAssemblyGroupName}";
      //var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(
      //  new List<GAssemblyGroup>() { gAssemblyGroup },
      //  gClassName: titularBaseClassName);
      //if (titularAssemblyUnitLookupPrimaryConstructorResults.gMethods.Count() == 0) {
      //  //ToDo: better exception handling
      //  throw new Exception("This should not happen");
      //}
      //var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<GAssemblyGroup>() { gAssemblyGroup },
      //  gClassName: titularClassName);
      //#endregion
      #region Initial StateMachine Configuration for this specific service
      gPrimaryConstructorBase.GStateConfigurations.AddRange(
        //titularAssemblyUnitLookupPrimaryConstructorResults.gMethods.First().GStateConfigurations.AddRange(
        new List<GStateConfiguration>() {
          new GStateConfiguration(
            gStateTransitions: new List<string>() {
              @"WaitingForARequestToGenerateAStateMachineConfiguration -> GeneratingAStateMachineConfiguration [label = ""RequestToGenerateAStateMachineReceived""]",
              @"GeneratingAStateMachineConfiguration -> WaitingForARequestToGenerateAStateMachineConfiguration [label = ""ReadyToReturnAStateMachineConfigurationMethod""]",
              @"WaitingForARequestToGenerateAStateMachineConfiguration -> WaitingForARequestToGenerateAStateMachineConfiguration [label = ""CancellationTokenActivated""]",
              @"GeneratingAStateMachineConfiguration -> WaitingForARequestToGenerateAStateMachineConfiguration [label = ""CancellationTokenActivated""]",
              @"WaitingForARequestToGenerateAStateMachineConfiguration -> ServiceFaulted [label = ""ExceptionCaught""]",
              @"GeneratingAStateMachineConfiguration -> ServiceFaulted [label = ""ExceptionCaught""]",
            },
            gStateConfigurationFluentChains: new List<string>() {
              // None
            }
          )
        }.AsEnumerable());
      #endregion

      #region Add UsingGroups specific to this library to the Titular Derived and Titular Base CompilationUnits
      #region Add the UsingGroup common to both the Titular Derived and Titular Base CompilationUnits
      //var gUsingGroup =
      //  new GUsingGroup(
      //    $"Usings specific to {gCompilationUnitDerived.GName} found in both Derived and Base");
      //foreach (var gName in new List<string>() {
      //  None
      //}) {
      //  var gUsing = new GUsing(gName);
      //  gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      //}
      //gCompilationUnitDerived.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      //gCompilationUnitBase.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Add the UsingGroups specific to the Titular Base CompilationUnit
      var gUsingGroup =
        new GUsingGroup(
          $"Usings specific to {gCompilationUnitBase.GName}");
      foreach (var gName in new List<string>() {"Stateless"}) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      gCompilationUnitBase.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #endregion
      //#region Add the MethodGroup containing new methods provided by this library to the Titular Base CompilationUnits 
      //var gMethodGroup =
      //  new GMethodGroup(
      //    gName:
      //    $"MethodGroup specific to {gCompilationUnitBase.GName}");
      //GMethod gMethod;
      //gMethod = MCreateStateConfigurationClass();
      //gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      //gClassBase.AddMethodGroup(gMethodGroup);
      //#endregion

      #region Add the StateConfiguration Class provided by this library to the Titular Base CompilationUnits
      var gClass = MCreateStateConfigurationClass();
      gNamespaceBase.GClasss.Add(gClass.Philote, gClass);
      #endregion
      /* ************************************************************************************ */
      #region Add UsingGroups specific to this library to the Titular Interface Derived and Titular Interface Base CompilationUnits
      #region Add the UsingGroup common to both the Titular InterfaceDerived and Titular InterfaceBase CompilationUnits
      //var gUsingGroup =
      //  new GUsingGroup(
      //    $"Usings specific to {gCompilationUnitDerived.GName} found in both Derived and Base");
      //foreach (var gName in new List<string>() {
      //  None
      //}) {
      //  var gUsing = new GUsing(gName);
      //  gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      //}
      //gTitularInterfaceDerivedCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      //gTitularInterfaceBaseCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Add the UsingGroups specific to the Titular interface Base CompilationUnit
      //var gUsingGroup =
      //  new GUsingGroup(
      //    $"Usings specific to {gTitularInterfaceBaseCompilationUnit.GName} found only in Base"");
      //foreach (var gName in new List<string>() {
      //  // None
      //}) {
      //  var gUsing = new GUsing(gName);
      //  gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      //}
      //gTitularInterfaceBaseCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #endregion
      /* ************************************************************************************ */
      #region Upate the ProjectUnits in both the Titular AssemblyUnit and Titular InterfacesAssemblyUnit
      #region References to be added to the Titular AssemblyUnit's ProjectUnit for this library
      #region References common to both Base and Derived Classes
      //var statelessStateMachineReferencesItemGroupInProjectUnit = MStatelessStateMachineReferencesItemGroupInProjectUnit();
      //gTitularAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(statelessStateMachineReferencesItemGroupInProjectUnit.Philote, statelessStateMachineReferencesItemGroupInProjectUnit);
      foreach (var o in new List<GItemGroupInProjectUnit>() {
      MStatelessStateMachineReferencesItemGroupInProjectUnit(),
      //    new GItemGroupInProjectUnit(
      //      "References common to both Base and Derived classes of {gCompilationUnitDerived.GName}",
      //      "None",
      //      new GBody(new List<string>() {
      //       "None",
      //      }))
        }
      ) {
        gTitularAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits
          .Add(o.Philote, o);
      }
      #endregion
      #region References specific to Base
      //foreach (var o in new List<GItemGroupInProjectUnit>() {
      //    new GItemGroupInProjectUnit(
      //      "References needed only by Base, specific to {gCompilationUnitDerived.GName}",
      //      "None",
      //      new GBody(new List<string>() {
      //       // None,
      //      }))
      //  }
      //) {
      //  gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits
      //    .Add(o.Philote, o);
      //}
      #endregion
      #endregion
      //#region ItemGroups for the ProjectUnit

      //#endregion
      #endregion
      //gAssemblyGroup.GAssemblyUnits.Add(gAssemblyUnit.Philote, gAssemblyUnit);
      /*******************************************************************************/
      #region Update the Interface Assembly for this library
      #region Add UsingGroups specific to this library to the Titular Derived Interface CompilationUnit and Titular Base Interface CompilationUnits
      #region Add the UsingGroups specific to the Titular Base CompilationUnit
      //var gUsingGroup =
      //  new GUsingGroup(
      //    $"Usings specific to {gCompilationUnitBaseInterface.GName} found only in Base"");
      //foreach (var gName in new List<string>() {
      //  // None
      //}) {
      //  var gUsing = new GUsing(gName);
      //  gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      //}
      //gCompilationUnitBaseInterface.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #endregion

      var titularInterfaceAssemblyName = $"{gAssemblyGroup.GName}.Interfaces";
      var lookupResultsForProjectAssembly = LookupProjectUnits(new List<GAssemblyGroup>() {gAssemblyGroup},
        gAssemblyUnitName: titularInterfaceAssemblyName);
      #region References to be added to the Titular Interfaces ProjectUnit for this library
      #region References common to both Titular and Base for this service
      //foreach (var o in new List<GItemGroupInProjectUnit>() {
      //   // None
      //  }
      //) {
      //  lookupResultsForProjectAssembly.gProjectUnits.First().GItemGroupInProjectUnits.Add(o.Philote, o);
      //}
      #endregion
      #region References unique to Base for this service's Interface
      //foreach (var o in new List<GItemGroupInProjectUnit>() {
      //    new GItemGroupInProjectUnit(
      //      "References needed only by Base, specific to {titularAssemblyUnitLookupPrimaryConstructorResults.gCompilationUnits.First().GName}",
      //      "None",
      //      new GBody(new List<string>() {
      //        // None,
      //      })
      //    )
      //  }
      //) {
      //  lookupResultsForProjectAssembly.gProjectUnits.First().GItemGroupInProjectUnits.Add(o.Philote, o);
      //}
      #endregion
      #endregion
      #endregion

      #region Finalize the Assemblygroup
      GAssemblyGroupCommonFinalizer(gAssemblyGroup, gClassDerived, gClassBase, gTitularInterfaceDerivedInterface,
        gTitularInterfaceBaseInterface);
      #endregion
      return gAssemblyGroup;
    }
    /*******************************************************************************/
    /*******************************************************************************/
    static GClass MCreateStateConfigurationClass(string gVisibility = "public") {
      //var gMethodArgumentList = new List<GArgument>() {
      //  new GArgument("requestorPhilote", "object"),
      //  new GArgument("callback", "object"),
      //  new GArgument("timerSignil", "object"),
      //  new GArgument("ct", "CancellationToken?")
      //};
      //var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      //foreach (var o in gMethodArgumentList) {
      //  gMethodArguments.Add(o.Philote, o);
      //}
      var gClass = new GClass("StateConfiguration", gVisibility:gVisibility);
      var gProperty = new GProperty("State", "State", "{get;}", "public");
      gClass.GPropertys.Add(gProperty.Philote, gProperty);
      gProperty = new GProperty("Trigger", "Trigger", "{get;}", "public");
      gClass.GPropertys.Add(gProperty.Philote, gProperty);
      gProperty = new GProperty("NextState", "State", "{get;}", "public");
      gClass.GPropertys.Add(gProperty.Philote, gProperty);
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in new List<GArgument>() {
        new GArgument("state", "State"), new GArgument("trigger", "Trigger"), new GArgument("nextState", "State"),
      }) {
        gMethodArguments.Add(o.Philote, o);
      }
      var gMethodDeclaration = new GMethodDeclaration(gName: "StateConfiguration",
        gVisibility: "public", isConstructor: true,
        gArguments: gMethodArguments);

      var gBody = new GBody(gStatements: new List<string>() {
        "State=state;", "Trigger=trigger;", "NextState=nextState;",
      });

      var gMethod = new GMethod(gMethodDeclaration, gBody);
      gClass.GMethods.Add(gMethod.Philote, gMethod);
      return gClass;
    }

  }
}
