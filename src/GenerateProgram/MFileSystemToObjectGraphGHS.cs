using System;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GUsingGroupExtensions;
using static GenerateProgram.GAttributeGroupExtensions;
using static GenerateProgram.Lookup;

//using AutoMapper.Configuration;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static GAssemblyGroup MFileSystemToObjectGraphGHS(
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;

      var gAssemblyGroupName = "FileSystemToObjectGraphGHS";
      var gAssemblyGroup = MAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles,
        baseNamespaceName, _gPatternReplacement);
      #region Select the Titular AssemblyUnit, Titular StateMachineDiGraph, TitularBase CompilationUnit, Namespace, Class, and Constructor
      var titularBaseClassName = $"{gAssemblyGroupName}Base";
      var titularClassName = $"{gAssemblyGroupName}";
      var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(
        new List<GAssemblyGroup>() {gAssemblyGroup},
        gClassName: titularBaseClassName);
      if (titularAssemblyUnitLookupPrimaryConstructorResults.gMethods.Count() == 0) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<GAssemblyGroup>() {gAssemblyGroup},
        gClassName: titularClassName);
      #endregion
      #region Method to process the ConsoleMonitorPattern inputString Observable
 
      #endregion
      #region Use MConsoleMonitorClient to implement the  ConsoleMonitor Pattern (includes adding the Transition from basic GHHS to ConsoleMonitorClient to the diGraph)
      MConsoleMonitorClient(gAssemblyGroup, titularAssemblyUnitLookupPrimaryConstructorResults, baseNamespaceName);
      MCreateProcessInputMethodForFileSystemToObjectGraphGHS(titularAssemblyUnitLookupPrimaryConstructorResults.gCompilationUnits.First());
      #endregion
      #region Initial StateMachine Configuration for this specific service
      titularAssemblyUnitLookupPrimaryConstructorResults.gMethods.First().GStateConfigurations.AddRange(
        new List<GStateConfiguration>() {
          new GStateConfiguration(
            gStateTransitions: new List<string>() {
              @"WaitingForInitialization ->InitiateContactWithConsoleMonitor [label = ""InitializationCompleteReceived""]", // ToDo: move this to ConsoleMonitorClient
              @"Connected -> Execute [label = ""inputline == 1""]",
              @"Connected -> Relinquish [label = ""inputline == 99""]",
              @"Connected -> Editing [label = ""inputline == 2""]",
              @"Editing -> Connected [label=""EditingComplete""]",
              @"Execute -> Connected [label = ""LongRunningTaskStartedNotificationSent""]",
              @"Relinquish -> Contacted [label = ""RelinquishNotificationAcknowledgementReceived""]",
              @"Connected ->ShutdownStarted [label = ""CancellationTokenActivated""]",
              @"Editing->ShutdownStarted[label = ""CancellationTokenActivated""]",
              @"Execute->ShutdownStarted[label = ""CancellationTokenActivated""]",
              @"Relinquish->ShutdownStarted[label = ""CancellationTokenActivated""]",
              @"Connected -> ServiceFaulted [label = ""ExceptionCaught""]",
              @"Editing ->ServiceFaulted [label = ""ExceptionCaught""]",
              @"Execute ->ServiceFaulted [label = ""ExceptionCaught""]",
              @"Relinquish ->ServiceFaulted [label = ""ExceptionCaught""]",
              @"Connected ->ShutdownStarted [label = ""StopAsyncActivated""]",
              @"Editing ->ShutdownStarted [label = ""StopAsyncActivated""]",
              @"Execute ->ShutdownStarted [label = ""StopAsyncActivated""]",
              @"Relinquish ->ShutdownStarted [label = ""StopAsyncActivated""]",
            },
            gStateConfigurationFluentChains: new List<string>() {
              // None
            }
          )
        }.AsEnumerable());
      #endregion

      #region Add UsingGroups specific to this service to the Titular and TitularBase CompilationUnits 
      #region Add the UsingGroup for this service to the Titular CompilationUnit
      var gUsingGroup =
        new GUsingGroup(
          $"Usings specific to {titularAssemblyUnitLookupDerivedClassResults.gCompilationUnits.First().GName}");
      foreach (var gName in new List<string>() {
        "ATAP.Utilities.ComputerInventory.Hardware", "ATAP.Utilities.Persistence",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      titularAssemblyUnitLookupDerivedClassResults.gCompilationUnits.First().GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Add the UsingGroup for this service to the Titular Base CompilationUnit
      gUsingGroup =
        new GUsingGroup(
          $"Usings specific to {titularAssemblyUnitLookupPrimaryConstructorResults.gCompilationUnits.First().GName}");
      foreach (var gName in new List<string>() {
        "ATAP.Utilities.ComputerInventory.Hardware", "ATAP.Utilities.Persistence",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      titularAssemblyUnitLookupPrimaryConstructorResults.gCompilationUnits.First().GUsingGroups
        .Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #endregion
      #region Add the MethodGroup for this service
      var gMethodGroup =
        new GMethodGroup(
          gName:
          $"MethodGroup specific to {titularAssemblyUnitLookupPrimaryConstructorResults.gCompilationUnits.First().GName}");
      GMethod gMethod;
      gMethod = MCreateConvertFileSystemToObjectGraphAsync(titularAssemblyUnitLookupPrimaryConstructorResults.gClasss
        .First());
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      titularAssemblyUnitLookupPrimaryConstructorResults.gClasss.First().AddMethodGroup(gMethodGroup);
      #endregion

      #region References to be added to the Titular ProjectUnit for this service
      #region References common to both Titular and Base for this service
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
        titularAssemblyUnitLookupPrimaryConstructorResults.gAssemblyUnits.First().GProjectUnit.GItemGroupInProjectUnits
          .Add(o.Philote, o);
      }
      #endregion
      #region References unique to Base for this service
      //foreach (var o in new List<GItemGroupInProjectUnit>() {
      //    new GItemGroupInProjectUnit(
      //      "References needed only by Base, specific to {titularAssemblyUnitLookupPrimaryConstructorResults.gCompilationUnits.First().GName}",
      //      "References to ...",
      //      new GBody(new List<string>() {
      //       // None,
      //      }))
      //  }
      //) {
      //  titularAssemblyUnitLookupPrimaryConstructorResults.gAssemblyUnits.First().GProjectUnit.GItemGroupInProjectUnits
      //    .Add(o.Philote, o);
      //}
      #endregion
      #endregion

      /*******************************************************************************/
      #region Update the Interface Assembly for this service
      var titularBaseInterfaceName = $"I{gAssemblyGroupName}Base";
      var titularInterfaceName = $"I{gAssemblyGroupName}";
      #region Select the Titular Interfaces AssemblyUnit, Titular Interface Base CompilationUnit, Namespace, and Interface
      var lookupTitularBaseInterfaceResults = LookupInterfaces(
        new List<GAssemblyGroup>() {gAssemblyGroup},
        gInterfaceName: titularBaseInterfaceName);
      if (lookupTitularBaseInterfaceResults.gInterfaces.Count() == 0) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      #endregion
      #region Select the Titular Interfaces AssemblyUnit, Titular Interface CompilationUnit, Namespace, and Interface
      var lookupTitularInterfaceResults = LookupInterfaces(
        new List<GAssemblyGroup>() {gAssemblyGroup},
        gInterfaceName: titularInterfaceName);
      if (lookupTitularInterfaceResults.gInterfaces.Count() == 0) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      #endregion
      #region Using groups for the Titular Interface and Titular Base Interface for this service
      #region Using groups for the Titular Interface for this service
      gUsingGroup =
        new GUsingGroup($"Usings specific to {lookupTitularInterfaceResults.gCompilationUnits.First().GName}");
      foreach (var gName in new List<string>() {
        "ATAP.Utilities.ComputerInventory.Hardware", "ATAP.Utilities.Persistence",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      lookupTitularInterfaceResults.gCompilationUnits.First().GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #region Using groups for the Titular Base Interface for this service
      gUsingGroup =
        new GUsingGroup($"Usings specific to {lookupTitularBaseInterfaceResults.gCompilationUnits.First().GName}");
      foreach (var gName in new List<string>() {
        "ATAP.Utilities.ComputerInventory.Hardware", "ATAP.Utilities.Persistence",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings.Add(gUsing.Philote, gUsing);
      }
      lookupTitularBaseInterfaceResults.gCompilationUnits.First().GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
      #endregion
      #endregion

      var titularInterfaceAssemblyName = $"{gAssemblyGroup.GName}.Interfaces";
      var lookupResultsForProjectAssembly = LookupProjectUnits(new List<GAssemblyGroup>() {gAssemblyGroup},
        gAssemblyUnitName: titularInterfaceAssemblyName);
      #region References to be added to the Titular ProjectUnit for this service
      #region References common to both Titular and Base for this service
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
        lookupResultsForProjectAssembly.gProjectUnits.First().GItemGroupInProjectUnits.Add(o.Philote, o);
      }
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

      #region Finalize the GHHS
      GAssemblyGroupGHHSFinalizer(gAssemblyGroup);
      #endregion
      return gAssemblyGroup;
    }
    /*******************************************************************************/
    /*******************************************************************************/
    public static void MUsingsForFileSystemToObjectGraphBaseAssembly(GCompilationUnit gCompilationUnit,
      string baseNamespace) {
      var gUsingGroup = new GUsingGroup("Usings For ConsoleMonitor Pattern").AddUsing(new List<GUsing>() {
        new GUsing($"{baseNamespace}.ConsoleMonitor"),
      });
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
    }
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
      // GMethod gMethod = CreateWriteAsyncMethod();
      // gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      // gMethod = MBuildMenuMethodForConsoleMonitorPatter();
      // gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      //gMethod = new GMethod().CreateReadCharMethod();
      //newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
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
    public static GMethod MCreateProcessInputMethodForFileSystemToObjectGraphGHS(GCompilationUnit gCompilationUnit) {
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in new List<GArgument>() {
        new GArgument("inputString", "string?"), new GArgument("genericHostsCancellationToken", "CancellationToken?"),
      }) {
        gMethodArguments.Add(o.Philote, o);
      }
      var gMethodDeclaration = new GMethodDeclaration(gName: $"ProcessInput{gCompilationUnit.GName}", gType: "void",
        gVisibility: "", isConstructor: false,
        gArguments: gMethodArguments);
      var gBody = new GBody(gStatements: new List<string>() {"#region TBD", " #endregion",});
      GComment gComment = new GComment(new List<string>() {
        "///  Used to process inputStrings from the ConsoleMonitorPattern"
      });
      return new GMethod(gMethodDeclaration, gBody, gComment);
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
        gVisibility: "private", gAccessModifier: "async", isConstructor: false,
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
