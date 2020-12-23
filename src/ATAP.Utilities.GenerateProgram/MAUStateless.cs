using System;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.Philote;
using static ATAP.Utilities.GenerateProgram.GAssemblyUnitExtensions;
using static ATAP.Utilities.GenerateProgram.GItemGroupInProjectUnitExtensions;
using static ATAP.Utilities.GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static ATAP.Utilities.GenerateProgram.Lookup;

//using AutoMapper.Configuration;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GMacroExtensions {
    public static IGAssemblyGroup MAUStateless(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true) {
      return MAUStateless(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, hasInterfaces,
        new GPatternReplacement());
    }
    public static IGAssemblyGroup MAUStateless(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true,
      IGPatternReplacement gPatternReplacement = default) {
      IGPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;


      var gAssemblyGroupBasicConstructorResult = MAssemblyGroupBasicConstructor(gAssemblyGroupName,
        subDirectoryForGeneratedFiles,
        baseNamespaceName, hasInterfaces, _gPatternReplacement);
      #region Initial StateMachine Configuration
      gAssemblyGroupBasicConstructorResult.GPrimaryConstructorBase.GStateConfiguration.GDOTGraphStatements.Add(
        @"
              WaitingForARequestToGenerateAStateMachineConfiguration -> GeneratingAStateMachineConfiguration [label = ""RequestToGenerateAStateMachineReceived""]
              GeneratingAStateMachineConfiguration -> WaitingForARequestToGenerateAStateMachineConfiguration [label = ""ReadyToReturnAStateMachineConfigurationMethod""]
              WaitingForARequestToGenerateAStateMachineConfiguration -> WaitingForARequestToGenerateAStateMachineConfiguration [label = ""CancellationTokenActivated""]
              GeneratingAStateMachineConfiguration -> WaitingForARequestToGenerateAStateMachineConfiguration [label = ""CancellationTokenActivated""]
              WaitingForARequestToGenerateAStateMachineConfiguration -> ServiceFaulted [label = ""ExceptionCaught""]
              GeneratingAStateMachineConfiguration -> ServiceFaulted [label = ""ExceptionCaught""]
            "
      );
      #endregion
      #region Add UsingGroups to the Titular Derived and Titular Base CompilationUnits
      #region Add UsingGroups common to both the Titular Derived and Titular Base CompilationUnits
      #endregion
      #region Add UsingGroups specific to the Titular Base CompilationUnit
      var gUsingGroup =
        new GUsingGroup(
          $"UsingGroup specific to {gAssemblyGroupBasicConstructorResult.GTitularBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {"Stateless", "System.Collections.Generic",}) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      gAssemblyGroupBasicConstructorResult.GTitularBaseCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #endregion
      #region Injected PropertyGroup For ConsoleSinkAndConsoleSource
      #endregion
      #region Add the MethodGroup containing new methods provided by this library to the Titular Base CompilationUnits
      #endregion
      #region Add additional classes provided by this library to the Titular Base CompilationUnit
      #region Add the StateConfiguration Class provided by this library to the Titular Base CompilationUnits
      //var gClass = MCreateStateConfigurationClass();
      //mCreateAssemblyGroupResult.GNamespaceBase.GClasss.Add(gClass.Philote, gClass);
      #endregion
      #endregion
      #region Add References used by the Titular Derived and Titular Base CompilationUnits to the ProjectUnit
      #region Add References used by both the Titular Derived and Titular Base CompilationUnits
      foreach (var o in new List<IGItemGroupInProjectUnit>() {
          new GItemGroupInProjectUnit("StatelessPackageReferences",
            "Packages for the Stateless lightweight StateMachine library",
            new GBody(new List<string>() {"<PackageReference Include=\"Stateless\" />",})),
        }
      ) {
        gAssemblyGroupBasicConstructorResult.GTitularAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits
          .Add(o.Philote, o);
      }
      #endregion
      #region Add References unique to the Titular Base CompilationUnit
      #endregion
      #endregion
      /*******************************************************************************/
      #region Update the Interface Assembly for this service
      #region Add UsingGroups for the Titular Derived Interface and Titular Base Interface
      #region Add UsingGroups common to both the Titular Derived Interface and the Titular Base Interface
      #endregion
      #region Add UsingGroups specific to the Titular Base Interface
      #endregion
      #endregion
      #endregion
      /* ************************************************************************************ */
      #region Upate the ProjectUnits in both the Titular AssemblyUnit and Titular InterfacesAssemblyUnit
      #region Add References for the Titular Interface ProjectUnit
      #region Add References common to both the Titular Derived Interface and Titular Base Interface
      #endregion
      #region Add References unique to the Titular Base Interface CompilationUnit
      #endregion
      #endregion
      #endregion
      #region Finalize the Assemblygroup
      GAssemblyGroupCommonFinalizer(gAssemblyGroupBasicConstructorResult);
      #endregion
      return gAssemblyGroupBasicConstructorResult.GAssemblyGroup;
    }
/*******************************************************************************/
/*******************************************************************************/
    static IGClass MCreateStateConfigurationClass(string gVisibility = "public") {
//var gMethodArgumentList = new List<IGArgument>() {
//  new GArgument("requestorPhilote", "object"),
//  new GArgument("callback", "object"),
//  new GArgument("timerSignil", "object"),
//  new GArgument("ct", "CancellationTokenFromCaller?")
//};
//var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
//foreach (var o in gMethodArgumentList) {
//  gMethodArguments.Add(o.Philote, o);
//}
      var gClass = new GClass("StateConfiguration", gVisibility: gVisibility);
      var gProperty = new GProperty("State", "State", "{get;}", "public");
      gClass.GPropertys.Add(gProperty.Philote, gProperty);
      gProperty = new GProperty("Trigger", "Trigger", "{get;}", "public");
      gClass.GPropertys.Add(gProperty.Philote, gProperty);
      gProperty = new GProperty("NextState", "State", "{get;}", "public");
      gClass.GPropertys.Add(gProperty.Philote, gProperty);
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
      foreach (var o in new List<IGArgument>() {
        new GArgument("state", "State"), new GArgument("trigger", "Trigger"), new GArgument("nextState", "State"),
      }) {
        gMethodArguments.Add(o.Philote, o);
      }
      var gMethodDeclaration = new GMethodDeclaration(gName: "StateConfiguration",
        gVisibility: "public", isConstructor: true,
        gArguments: gMethodArguments);
      var gBody = new GBody(
        gStatements: new List<string>() {"State=state;", "Trigger=trigger;", "NextState=nextState;",});
      var gMethod = new GMethod(gMethodDeclaration, gBody);
      gClass.GMethods.Add(gMethod.Philote, gMethod);
      return gClass;
    }
  }
}
