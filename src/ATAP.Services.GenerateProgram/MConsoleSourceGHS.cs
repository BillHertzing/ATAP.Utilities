using System;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.Lookup;

//using AutoMapper.Configuration;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblyGroup MConsoleSourceGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default) {
      return MConsoleSourceGHS(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName,
        new GPatternReplacement());
    }
    public static GAssemblyGroup MConsoleSourceGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      var mCreateAssemblyGroupResult = MAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, _gPatternReplacement);
      #region Initial StateMachine Configuration
      mCreateAssemblyGroupResult.gPrimaryConstructorBase.GStateConfiguration.GDOTGraphStatements.Add(
    @"
          WaitingForInitialization ->BlockingOnConsoleInReadLineAsync [label = ""InitializationCompleteReceived""]
          BlockingOnConsoleInReadLineAsync -> ServiceFaulted [label = ""ExceptionCaught""]
          BlockingOnConsoleInReadLineAsync -> ShutdownStarted [label = ""CancellationTokenActivated""]
          "
      );
      #endregion

      #region Add UsingGroups to the Titular Derived and Titular Base CompilationUnits
      #region Add UsingGroups common to both the Titular Derived and Titular Base CompilationUnits
      #endregion
      #region Add UsingGroups specific to the Titular Base CompilationUnit
      var gUsingGroup =
        new GUsingGroup(
          $"UsingGroup specific to {mCreateAssemblyGroupResult.gTitularBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {"System.Reactive.Linq", "System.Reactive.Concurrency",}) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.gTitularBaseCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #endregion
      #region Injected PropertyGroup For ConsoleSinkAndConsoleSource
      #endregion
      #region Add the MethodGroup containing new methods provided by this library to the Titular Base CompilationUnit
      var gMethodGroup =
        new GMethodGroup(
          gName:
          $"MethodGroup specific to {mCreateAssemblyGroupResult.gClassBase.GName}");
      GMethod gMethod;
      gMethod = CreateConsoleReadLineAsyncAsObservableMethod();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      mCreateAssemblyGroupResult.gClassBase.AddMethodGroup(gMethodGroup);
      #endregion
      #region Add additional classes provided by this library to the Titular Base CompilationUnit
      #endregion
      #region Add References used by the Titular Derived and Titular Base CompilationUnits to the ProjectUnit
      #region Add References used by both the Titular Derived and Titular Base CompilationUnits
      foreach (var o in new List<GItemGroupInProjectUnit>() {ReactiveUtilitiesReferencesItemGroupInProjectUnit(),}
      ) {
        mCreateAssemblyGroupResult.gTitularAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits
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
      #region Add References for the Titular Interface ProjectUnit
      #region Add References common to both the Titular Derived Interface and Titular Base Interface
      foreach (var o in new List<GItemGroupInProjectUnit>() {ReactiveUtilitiesReferencesItemGroupInProjectUnit()}
      ) {
        mCreateAssemblyGroupResult.gTitularInterfaceAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits
          .Add(o.Philote, o);
      }
      #endregion
      #region Add References unique to the Titular Base Interface CompilationUnit
      #endregion
      #endregion
      #endregion
      #region Finalize the GHHS
      GAssemblyGroupGHHSFinalizer(mCreateAssemblyGroupResult);
      #endregion
      return mCreateAssemblyGroupResult.gAssemblyGroup;
    }
    /*******************************************************************************/
    /*******************************************************************************/
    static GMethod CreateConsoleReadLineAsyncAsObservableMethod(string gAccessModifier = "") {
      var gMethodArgumentList = new List<GArgument>() {
        // None
      };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in gMethodArgumentList) {
        gMethodArguments.Add(o.Philote, o);
      }
      return new GMethod(
        new GMethodDeclaration(gName: "ConsoleReadLineAsyncAsObservable", gType: "IObservable<string>",
          gVisibility: "public", gAccessModifier: gAccessModifier, isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            @"     return",
            @"         Observable",
            @"             .FromAsync(() => Console.In.ReadLineAsync()) // This is actually a BLOCKING operation, see ?? for workaround",
            @"             .Repeat()",
            @"             .Publish()",
            @"             .RefCount()",
            @"             .SubscribeOn(Scheduler.Default);",
          }),
        new GComment(
          new List<string>() {"// Convert the Console.In.ReadLineAsync into an IObservable in this service",}));
    }
  }
}
