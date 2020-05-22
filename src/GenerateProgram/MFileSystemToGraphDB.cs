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
    public static GAssemblyGroup MFileSystemToObjectGraph(
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;

      var gAssemblyGroupName = "FilesystemToObjectGraphGHService";
      var gAssemblyGroup = GAssemblyGroupGHHSConstructor(gAssemblyGroupName, subDirectoryForGeneratedFiles, baseNamespaceName, _gPatternReplacement);
      #region Declare and populate the initial rawDiGraph, which handles basic states for a GHHS
      List<string> rawDiGraph = new List<string>() {
        @"WaitingForInitialization ->ServiceFaulted [label = ""AnyException""]",
        @"ServiceFaulted ->ShutdownStarted [label = ""CancellationTokenActivated""]",
        @"ServiceFaulted ->ShutdownStarted [label = ""StopAsyncActivated""]",
        @"ShutdownStarted->ShutDownComplete [label = ""AllShutDownStepsCompleted""]",
      };
      #endregion
      #region Select the Titular AssemblyUnit, TitularBase CompilationUnit, Namespace, Class, and Constructor
      var titularBaseClassName = $"{gAssemblyGroupName}Base";
      var lookupResultsForTitularBase = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>() { gAssemblyGroup }, gClassName: titularBaseClassName);
      if (lookupResultsForTitularBase.gMethods.Count() == 0) {
        //ToDo: better exception handling
        throw new Exception("This should not happen");
      }
      #endregion
      #region Add Transition from basic GHHS to ConsoleMonitorClient to the diGraph
      rawDiGraph = new List<string>() {
        "WaitingForInitialization ->InitiateContactWithConsoleMonitor [label = \"InitializationCompleteReceived\"]",
      };
      #endregion
      #region Use MConsoleMonitorClient to implement the  ConsoleMonitor Pattern
      MConsoleMonitorClient(gAssemblyGroup, lookupResultsForTitularBase, baseNamespaceName, rawDiGraph);
      #endregion
      #region StateMachine Configuration for this specific service
      rawDiGraph.AddRange(new List<string>(){
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
      });
      MStateMachineDetails(lookupResultsForTitularBase, rawDiGraph);
      #endregion

      #region Add the UsingGroup for this service
      var gUsingGroup = new GUsingGroup($"Usings specific to {lookupResultsForTitularBase.gCompilationUnits.First().GName}");
      foreach (var gName in new List<string>() {
        "System.Text",
        "ATAP.Utilities.ComputerInventory.Hardware",
        "ATAP.Utilities.Persistence",
      }) {
        var gUsing = new GUsing(gName);
        gUsingGroup.GUsings[gUsing.Philote] = gUsing;
      }
      lookupResultsForTitularBase.gCompilationUnits.First().GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
      #endregion
      #region Add the MethodGroup for this service
      var gMethodGroup =
        new GMethodGroup(gName: $"MethodGroup specific to {lookupResultsForTitularBase.gCompilationUnits.First().GName}");
      GMethod gMethod;
      gMethod = MCreateConvertFileSystemToObjectGraphAsync(lookupResultsForTitularBase.gClasss.First());
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      lookupResultsForTitularBase.gClasss.First().AddMethodGroup(gMethodGroup);
      #endregion

      #region References to be added to the Titular ProjectUnit
      #region References common to both Titular and Base
      foreach (var o in new List<GItemGroupInProjectUnit>() {
        new GItemGroupInProjectUnit("References specific to {lookupResultsForTitularBase.gCompilationUnits.First().GName}",
          "References to the Hardware, Persistence, and Progress classes and methods", new GBody(new List<string>() {
            //"<PackageReference Include=\"ATAP.Utilities.ComputerInventory.Hardware\" />",
          })
        )}
      ) {
        lookupResultsForTitularBase.gAssemblyUnits.First().GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o);
      }
      #endregion
      #region References unique to Base
      foreach (var o in new List<GItemGroupInProjectUnit>() {
        new GItemGroupInProjectUnit("References specific to {lookupResultsForTitularBase.gCompilationUnits.First().GName}",
          "References to the Hardware, Persistence, and Progress classes and methods", new GBody(new List<string>() {
            "<PackageReference Include=\"ATAP.Utilities.ComputerInventory.Hardware.Extensions\" />",
          })
          )}
      ) {
        lookupResultsForTitularBase.gAssemblyUnits.First().GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o);
      }
      #endregion
      #endregion

      /*******************************************************************************/
      #region Populate the Interface Assembly
      #region Populate the Interfaces
      GAssemblyGroupPopulateInterfaces(gAssemblyGroup);
      #endregion
      #region Lookup the InterfaceAssembly major parts
      var titularInterfaceAssemblyName = $"{gAssemblyGroup.GName}.Interfaces";
      var lookupResultsForProjectAssembly = LookupProjectUnits(new List<GAssemblyGroup>() { gAssemblyGroup }, gAssemblyUnitName: titularInterfaceAssemblyName);
      #endregion
      #region ReferenceItemGroups for the ProjectUnit that are unique to this service and used by the Interface Assembly
      foreach (var o in new List<GItemGroupInProjectUnit>() {
          new GItemGroupInProjectUnit("ReferencesUsedByFilesystemToObjectGraph.Interface",
            "References used by the FilesystemToObjectGraph Interface", new GBody(new List<string>() {
              "<PackageReference Include=\"ATAP.Utilities.Persistence.Interfaces\" />",
              //"<PackageReference Include=\"ATAP.Utilities.ComputerInventory.Hardware\" />",
            }))
      }
      ) {
        lookupResultsForProjectAssembly.gProjectUnits.First().GItemGroupInProjectUnits.Add(o.Philote, o);
      }

      #endregion
      #endregion
      return gAssemblyGroup;
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
    public static void MUsingsForFilesystemToObjectGraphInterfaceAssembly(GCompilationUnit gCompilationUnit, string baseNamespace) {
      var gUsingGroup = new GUsingGroup("Usings For ConsoleMonitor Pattern").AddUsing(new List<GUsing>() {
        new GUsing($"{baseNamespace}.ConsoleMonitor"),
      });
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
    }

    public static GMethod MCreateConvertFileSystemToObjectGraphAsync(GClass gClass) {
      var gMethodArgumentList = new List<GArgument>() {
        new GArgument("rootString", "string"),
        new GArgument("asyncFileReadBlockSize", "int"),
        new GArgument("enableHash", "bool"),
        new GArgument("convertFileSystemToGraphProgress", "ConvertFileSystemToGraphProgress"),
        new GArgument("persistence", "Persistence<IInsertResultsAbstract>"),
        new GArgument("pickAndSave", "PickAndSave<IInsertResultsAbstract>"),
        new GArgument("cancellationToken", "CancellationToken"),
      };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in gMethodArgumentList) {
        gMethodArguments.Add(o.Philote, o);
      }
      return new GMethod(
        new GMethodDeclaration(gName: "ConvertFileSystemToObjectGraphAsync",
          gType: "Task<ConvertFileSystemToGraphResult>",
          gVisibility: "private", gAccessModifier: "async", isConstructor: false,
          gArguments: gMethodArguments),
        gBody:
        new GBody(new List<string>() {
          "cancellationToken?.ThrowIfCancellationRequested();",
          "await Task.Delay(10000);",
          "return new ConvertFileSystemToGraphResult();",
        }),
        new GComment(new List<string>() {
          "/// <summary>",
          "/// Convert the contents of a complete Filesystem (or portion therof) to an Graph representation",
          "/// </summary>",
          "/// <param name=\"\"></param>",
          "/// <param name=\"\"></param>",
          "/// <param name=\"cancellationToken\"></param>",
          "/// <returns>Task<ConvertFileSystemToGraphResult></returns>",
        }));

    }
  }
}
