using System;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.Philote;
using static ATAP.Utilities.GenerateProgram.GAssemblyGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GMethodGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GMethodExtensions;
using static ATAP.Utilities.GenerateProgram.GUsingGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GAttributeGroupExtensions;
using static ATAP.Utilities.GenerateProgram.Lookup;
//using AutoMapper.Configuration;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblyGroup MFileSystemToObjectGraphGHS(string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true) {
      return MFileSystemToObjectGraphGHS(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, hasInterfaces, new GPatternReplacement()  );
    }

    public static GAssemblyGroup MFileSystemToObjectGraphGHS( string gAssemblyGroupName,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      var mCreateAssemblyGroupResult = MAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, hasInterfaces, _gPatternReplacement);
      #region Initial StateMachine Configuration
      mCreateAssemblyGroupResult.gPrimaryConstructorBase.GStateConfiguration.GDOTGraphStatements.Add(
    @"
          WaitingForInitialization ->InitiateContactWithConsoleMonitor [label = ""InitializationCompleteReceived""] // ToDo: move this to ConsoleMonitorClient
          Connected -> Execute [label = ""inputline == 1""]
          Connected -> Relinquish [label = ""inputline == 99""]
          Connected -> Editing [label = ""inputline == 2""]
          Editing -> Connected [label=""EditingComplete""]
          Execute -> Connected [label = ""LongRunningTaskStartedNotificationSent""]
          Relinquish -> Contacted [label = ""RelinquishNotificationAcknowledgementReceived""]
          Connected ->ShutdownStarted [label = ""CancellationTokenActivated""]
          Editing->ShutdownStarted[label = ""CancellationTokenActivated""]
          Execute->ShutdownStarted[label = ""CancellationTokenActivated""]
          Relinquish->ShutdownStarted[label = ""CancellationTokenActivated""]
          Connected -> ServiceFaulted [label = ""ExceptionCaught""]
          Editing ->ServiceFaulted [label = ""ExceptionCaught""]
          Execute ->ServiceFaulted [label = ""ExceptionCaught""]
          Relinquish ->ServiceFaulted [label = ""ExceptionCaught""]
          Connected ->ShutdownStarted [label = ""StopAsyncActivated""]
          Editing ->ShutdownStarted [label = ""StopAsyncActivated""]
          Execute ->ShutdownStarted [label = ""StopAsyncActivated""]
          Relinquish ->ShutdownStarted [label = ""StopAsyncActivated""]
        "
      );
      #endregion
      #region Add UsingGroups to the Titular Derived and Titular Base CompilationUnits 
      #region Add UsingGroups common to both the Titular Derived and Titular Base CompilationUnits
      var gUsingGroup =
        new GUsingGroup(
          $"UsingGroup common to both {mCreateAssemblyGroupResult.gTitularDerivedCompilationUnit.GName} and {mCreateAssemblyGroupResult.gTitularBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {
        "ATAP.Utilities.ComputerInventory.Hardware", "ATAP.Utilities.Persistence",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.gTitularDerivedCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      mCreateAssemblyGroupResult.gTitularBaseCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Add UsingGroups specific to the Titular Base CompilationUnit
      #endregion
      #endregion
      #region Injected PropertyGroup For ConsoleSinkAndConsoleSource
      #endregion
      #region Add the MethodGroup containing new methods provided by this library to the Titular Base CompilationUnits 
      var gMethodGroup =
        new GMethodGroup(
          gName:
          $"MethodGroup specific to {mCreateAssemblyGroupResult.gTitularBaseCompilationUnit.GName}");
      GMethod gMethod;
      gMethod = MCreateConvertFileSystemToObjectGraphAsync(mCreateAssemblyGroupResult.gClassBase);
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      mCreateAssemblyGroupResult.gClassBase.AddMethodGroup(gMethodGroup);
      #endregion
      #region Add additional classes provided by this library to the Titular Base CompilationUnit
      #endregion
      #region Add References used by the Titular Derived and Titular Base CompilationUnits to the ProjectUnit 
      #region Add References used by both the Titular Derived and Titular Base CompilationUnits
      foreach (var o in new List<GItemGroupInProjectUnit>() {
          new GItemGroupInProjectUnit(
            "References common to both Titular and Base specific to {titularAssemblyUnitLookupPrimaryConstructorResults.gCompilationUnits.First().GName}",
            "References to the Hardware, Persistence, and Progress classes and methods",
            new GBody(new List<string>() {
              "<PackageReference Include=\"ATAP.Utilities.ComputerInventory.Hardware.Extensions\" />",
              "<PackageReference Include=\"ATAP.Utilities.Persistence.Interfaces\" />",
              "<PackageReference Include=\"ATAP.Utilities.Persistence\" />",
            })
          )
        }
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
      #region Add UsingGroups common to both the Titular Derived Interface CompilationUnit and the Titular Base Interface CompilationUnit
      gUsingGroup =
        new GUsingGroup(
        $"UsingGroup common to both {mCreateAssemblyGroupResult.gTitularInterfaceDerivedCompilationUnit.GName} and {mCreateAssemblyGroupResult.gTitularInterfaceBaseCompilationUnit.GName}");
      foreach (var gName in new List<string>() {
        "ATAP.Utilities.ComputerInventory.Hardware",
        "ATAP.Utilities.Persistence",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      mCreateAssemblyGroupResult.gTitularInterfaceDerivedCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      mCreateAssemblyGroupResult.gTitularInterfaceBaseCompilationUnit.GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Add UsingGroups specific to the Titular Base Interface
      #endregion
      #endregion
      #endregion
       /* ************************************************************************************ */
      #region Update the ProjectUnits in both the Titular AssemblyUnit and Titular InterfacesAssemblyUnit
      #region Add References for the Titular Interface ProjectUnit
      #region Add References common to both the Titular Derived Interface and Titular Base Interface
      foreach (var o in new List<GItemGroupInProjectUnit>() {
          new GItemGroupInProjectUnit(
            $"References common to both  {mCreateAssemblyGroupResult.gTitularDerivedCompilationUnit.GName} and {mCreateAssemblyGroupResult.gTitularBaseCompilationUnit.GName}",
            "References to the Hardware, Persistence, and Progress classes and methods",
            new GBody(new List<string>() {
              "<PackageReference Include=\"ATAP.Utilities.ComputerInventory.Hardware.Extensions\" />",
              "<PackageReference Include=\"ATAP.Utilities.Persistence.Interfaces\" />",
              "<PackageReference Include=\"ATAP.Utilities.Persistence\" />",
            })
          )
        }
      ) {
        mCreateAssemblyGroupResult.gTitularInterfaceAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o);
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

    public static void MPropertyGroupForFileSystemToObjectGraphBaseAssembly(GClass gClass) {
      var gPropertyGroup = new GPropertyGroup("Propertys specific to the FileSystemToObjectGraph");
      foreach (var o in new List<GProperty>() {
        // new GProperty("?", gType: "IDisposable",gAccessors: "{ get; set; }", gVisibility: "protected internal"),
        // new GProperty("Choices", gType: "Dictionary<String,IEnumerable<string>>", gAccessors: "{ get; }", gVisibility: "protected internal"),
      }) {
        gPropertyGroup.GPropertys.Add(o.Philote, o);
      }
      gClass.AddPropertyGroups(gPropertyGroup);
    }
    public static void
      MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedPropertyInFileSystemToObjectGraphBaseAssembly(
        GClass gClass,
        GMethod gConstructor) {
      var gPropertyGroup = new GPropertyGroup("Injected Propertys specific to the FileSystemToObjectGraph");
      gClass.AddPropertyGroups(gPropertyGroup);
      // foreach (var o in new List<string>() { "ConsoleMonitor" }) {
      // gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, o, gPropertyGroupId: gPropertyGroup.Philote);
      // }
    }
    public static void MMethodGroupForFileSystemToObjectGraphBaseAssembly(GClass gClass) {
      var gMethodGroup =
        new GMethodGroup(gName: "MethodGroup specific to the FileSystemToObjectGraph");
      // None
      gClass.AddMethodGroup(gMethodGroup);
    }
    public static void
      MProjectReferenceItemGroupInProjectUnitForFileSystemToObjectGraphBaseAssembly(GAssemblyUnit gAssemblyUnit) {
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ReferencesUsedByFileSystemToObjectGraph",
        "References used by the FileSystemToObjectGraph", new GBody(new List<string>() {
          "<PackageReference Include=\"ATAP.Utilities.ComputerInventory.Hardware.Extensions\" />",
          "<PackageReference Include=\"ATAP.Utilities.ComputerInventory.ProcessInfo.Models\" />",
          "<PackageReference Include=\"ATAP.Utilities.ComputerInventory.Software.Enumerations\" />",
          "<PackageReference Include=\"ATAP.Utilities.Persistence.Interfaces\" />",
          "<PackageReference Include=\"ATAP.Utilities.Persistence\" />",
          "<PackageReference Include=\"ATAP.Utilities.Extensions.Persistence\" />",
        }));
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gItemGroupInProjectUnit.Philote,
        gItemGroupInProjectUnit);
    }
    public static (GBody, GComment) MCreateProcessInputMethodForFileSystemToObjectGraphGHS() {
      GBody gBody = new GBody(gStatements: new List<string>() {"#region TBD", " #endregion",});
      GComment gComment = new GComment(new List<string>() {
        "///  Used to process inputStrings from the ConsoleMonitorPattern"
      });
      return (gBody, gComment);
    }
    public static GMethod MCreateConvertFileSystemToObjectGraphAsync(GClass gClass) {
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in new List<GArgument>() {
        new GArgument("rootString", "string"),
        new GArgument("asyncFileReadBlockSize", "int"),
        new GArgument("enableHash", "bool"),
        new GArgument("convertFileSystemToGraphProgress", "ConvertFileSystemToGraphProgress"),
        new GArgument("persistence", "Persistence<IInsertResultsAbstract>"),
        new GArgument("pickAndSave", "PickAndSave<IInsertResultsAbstract>"),
        new GArgument("cancellationToken", "CancellationToken?"),
      }) {
        gMethodArguments.Add(o.Philote, o);
      }
      var gMethodDeclaration = new GMethodDeclaration(gName: "ConvertFileSystemToObjectGraphAsync",
        gType: "Task<ConvertFileSystemToGraphResult>",
        gVisibility: "public", gAccessModifier: "async", isConstructor: false,
        gArguments: gMethodArguments);
      var gBody = new GBody(new List<string>() {
        "cancellationToken?.ThrowIfCancellationRequested();",
        "await Task.Delay(10000);",
        "return new ConvertFileSystemToGraphResult();",
      });
      var gComment = new GComment(new List<string>() {
        "/// <summary>",
        "/// Convert the contents of a complete FileSystem (or portion thereof) to an Graph representation",
        "/// </summary>",
        "/// <param name=\"\"></param>",
        "/// <param name=\"\"></param>",
        "/// <param name=\"cancellationToken\"></param>",
        "/// <returns>Task<ConvertFileSystemToGraphResult></returns>",
      });
      return new GMethod(gMethodDeclaration, gBody, gComment);
    }
  }
}
