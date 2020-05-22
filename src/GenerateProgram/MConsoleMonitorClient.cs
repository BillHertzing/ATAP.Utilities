using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.StringConstants;
//using AutoMapper.Configuration;
using static GenerateProgram.GPropertyGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GUsingGroupExtensions;
using static GenerateProgram.GAssemblyUnitExtensions;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static void MConsoleMonitorClient(GAssemblyGroup gAssemblyGroup, (
      IEnumerable<GAssemblyUnit> gAssemblyUnits,
      IEnumerable<GCompilationUnit> gCompilationUnits,
      IEnumerable<GNamespace> gNamespacess,
      IEnumerable<GClass> gClasss,
      IEnumerable<GMethod> gMethods) lookupResultsTuple, string baseNamespaceName = "", List<string> rawDiGraph = default) {
      MConsoleMonitorClient(gAssemblyGroup, lookupResultsTuple.gAssemblyUnits.First(), lookupResultsTuple.gCompilationUnits.First(), lookupResultsTuple.gNamespacess.First(), lookupResultsTuple.gClasss.First(), lookupResultsTuple.gMethods.First(),baseNamespaceName:baseNamespaceName);
    }
    public static void MConsoleMonitorClient(GAssemblyGroup gAssemblyGroup, GAssemblyUnit gAssemblyUnit = default, GCompilationUnit gCompilationUnit = default, GNamespace gNamespace = default, GClass gClass = default, GMethod gMethod = default,  string baseNamespaceName = "", List<string> rawDiGraph = default) {
      #region Titular Base Assembly Unit
      MConsoleMonitorClientBase(gAssemblyUnit, gCompilationUnit, gNamespace, gClass, gMethod, baseNamespaceName);
    }

    #endregion

    public static void MConsoleMonitorClientBase(GAssemblyUnit gAssemblyUnit, GCompilationUnit gCompilationUnit,
      GNamespace gNamespace, GClass gClass, GMethod gConstructor, string baseNamespaceName) {
      #region Titular Assembly Unit, TitularBase CompilationUnit, TitularBase Namespace, , TitularBase Class TitularBase Primary Constructor
      #region UsingGroup
      MUsingsForConsoleMonitorPattern(gCompilationUnit, baseNamespaceName);
      #endregion
      #region PropertyGroup ForConsoleMonitorPattern
      MPropertyGroupForConsoleMonitorPattern(gClass);
      #endregion
      #region Injected PropertyGroup ForConsoleMonitorPattern
      MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedConsoleMonitorService(gClass, gConstructor);
      #endregion
      #region MethodGroup ForConsoleMonitorPattern
      MMethodGroupForConsoleMonitorPattern(gClass);
      #endregion
      #region ItemGroups for the ProjectUnit For ConsoleMonitorPattern
      MReferenceItemGroupInBaseProjectUnitForConsoleMonitorService(gAssemblyUnit);
      #endregion
      #endregion
    }
    public static void MUsingsForConsoleMonitorPattern(GCompilationUnit gCompilationUnit, string baseNamespace) {
      var gUsingGroup = new GUsingGroup("Usings For ConsoleMonitor Pattern").AddUsing(new List<GUsing>() {
        new GUsing($"{baseNamespace}.ConsoleMonitor"),
        new GUsing("System.Text"),
      });
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
    }
    public static void MPropertyGroupForConsoleMonitorPattern(GClass gClass) {
      var gPropertyGroup = new GPropertyGroup("Propertys needed to interoperate with the ConsoleMonitor Service");
      foreach (var o in new List<GProperty>() {
        new GProperty("SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle", gType: "IDisposable",
          gAccessors: "{ get; set; }", gVisibility: "protected internal"),
        // new GProperty("Choices", gType: "Dictionary<String,IEnumerable<string>>", gAccessors: "{ get; }", gVisibility: "protected internal"),
      }) {
        gPropertyGroup.GPropertys.Add(o.Philote, o);
      }
      gClass.AddPropertyGroups(gPropertyGroup);
    }
    public static void MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedConsoleMonitorService(GClass gClass,
      GMethod gConstructor) {
      var gPropertyGroup = new GPropertyGroup("Injected Property for ConsoleMonitor Service");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var o in new List<string>() { "ConsoleMonitor" }) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, o, gPropertyGroupId: gPropertyGroup.Philote);
      }
    }
    public static void MMethodGroupForConsoleMonitorPattern(GClass gClass) {
      var gMethodGroup =
        new GMethodGroup(gName: "MethodGroup ForConsoleMonitorPattern");
      GMethod gMethod = MCreateWriteAsyncMethodForConsoleMonitorPattern();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      gMethod = MCreateWriteMethodForConsoleMonitorPattern();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      gMethod = MBuildMenuMethodForConsoleMonitorPattern();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      //gMethod = new GMethod().CreateReadCharMethod();
      //newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gClass.AddMethodGroup(gMethodGroup);
      gClass.AddMethodGroup(MCreateStateTransitionMethodGroupForConsoleMonitorPattern());
    }
    public static void
      MReferenceItemGroupInBaseProjectUnitForConsoleMonitorService(GAssemblyUnit gAssemblyUnit) {

      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ReferencesUsedByConsoleMonitorServiceClients",
        "Packages referenced by Clients wishing to use the GHConsoleMonitorService", new GBody(new List<string>() {
          "<PackageReference Include=\"ConsoleMonitor.Interfaces\" />",
          "<PackageReference Include=\"ConsoleMonitor\" />",
        }));
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gItemGroupInProjectUnit.Philote,
        gItemGroupInProjectUnit);
    }
    public static void
      MReferenceItemGroupInInterfaceProjectUnitForConsoleMonitorService(GAssemblyUnit gAssemblyUnit) {

      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ReferencesUsedByConsoleMonitorServiceClients",
        "Packages referenced by Clients wishing to use the GHConsoleMonitorService", new GBody(new List<string>() {
          "<PackageReference Include=\"ConsoleMonitor.Interfaces\" />",
        }));
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gItemGroupInProjectUnit.Philote,
        gItemGroupInProjectUnit);
    }

    public static GMethod MBuildMenuMethodForConsoleMonitorPattern() {
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in new List<GArgument>() {
        new GArgument("mesg","StringBuilder"),
        new GArgument("choices","IEnumerable<string>"),
        new GArgument("cancellationToken","CancellationToken?")
      }) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "BuildMenu", gType: "void",
          gVisibility: "private", gAccessModifier: "", isConstructor: false,
          gArguments: gMethodArguments),
        gBody:
        new GBody(new List<string>() {
          "cancellationToken?.ThrowIfCancellationRequested();",
          "mesg.Clear();",
          "foreach (var choice in choices) {",
          "  mesg.Append(choice);",
          "}",
        }),
        new GComment(new List<string>() {
          "/// <summary>",
          "/// Build a multiline menu from the choices, and send to stdout",
          "/// </summary>",
          "/// <param name=\"mesg\"></param>",
          "/// <param name=\"choices\"></param>",
          "/// <param name=\"cancellationToken\"></param>",
          "/// <returns></returns>",
        }));
    }


    public static GMethod MCreateReadLineMethodForConsoleMonitorPattern() {
      var gMethodArgumentList = new List<GArgument>() {
        new GArgument("inService","TypeOfHostedservice"),
        //new GArgument("mesg","string"),
        new GArgument("ct","CancellationToken?")
      };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "SubscribeToConsoleMonitorReadLine", gType: "IDisposable",
          gVisibility: "private", gAccessModifier: "", isConstructor: false,
          gArguments: gMethodArguments),
        gBody:
        new GBody(new List<string>() {
          "return Task.CompletedTask;"
        }),
        new GComment(new List<string>() {
          "// Subscribes to the ConsoleMonitor Todo: finish this comment"
        }));
    }

    public static GMethod MCreateWriteAsyncMethodForConsoleMonitorPattern(string gAccessModifier = "") {
      var gMethodArgumentList = new List<GArgument>() {
    new GArgument("mesg","string"),
    new GArgument("ct","CancellationToken?")
  };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "WriteAsync", gType: "Task",
          gVisibility: "private", gAccessModifier: gAccessModifier + " async", isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            "StateMachine.Fire(Trigger.WriteAsyncStarted);",
        "ct?.ThrowIfCancellationRequested();",
        "var task = await ConsoleMonitor.WriteAsync(mesg).ConfigureAwait(false);",
        "if (!task.IsCompletedSuccessfully) {",
        "if (task.IsCanceled) {",
        "// Ignore if user cancelled the operation during a large file output (internal cancellation)",
        "// re-throw if the cancellation request came from outside the ConsoleMonitor",
        "/// ToDo: evaluate the linked, inner, and external tokens",
        "throw new OperationCanceledException();",
        "}",
        "else if (task.IsFaulted) {",
        "//ToDo: Go through the inner exception",
        "//foreach (var e in t.Exception) {",
        "//  https://docs.microsoft.com/en-us/dotnet/standard/io/handling-io-errors",
        "// ToDo figure out what to do if the output stream is closed",
        "throw new Exception(\"ToDo: task.faulted from ioutService.WriteMessageAsync n WriteMessageSafelyAsync\");",
        "//}",
        "}",
        "}",
        "StateMachine.Fire(Trigger.WriteAsyncFinished);",
        "return Task.CompletedTask;"
          }),
        new GComment(new List<string>() {
      "// Used to write a string to the ConsoleMonitor service"
        }));
    }

    static GMethod MCreateWriteMethodForConsoleMonitorPattern(string gAccessModifier = "") {
      var gMethodArgumentList = new List<GArgument>() {
        new GArgument("mesg","string"),
        new GArgument("ct","CancellationToken?")
      };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "Write", gType: "void",
          gVisibility: "private", gAccessModifier: gAccessModifier, isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            "StateMachine.Fire(Trigger.WriteStarted);",
            "ct?.ThrowIfCancellationRequested();",
            "ConsoleMonitor.Write(mesg);",
            "StateMachine.Fire(Trigger.WriteFinished);",
          }),
        new GComment(new List<string>() {
          "// Used to write a string to Write method of the ConsoleSink service"
        }));
    }

    public static GMethodGroup MCreateStateTransitionMethodGroupForConsoleMonitorPattern() {

      #region ConsoleMonitorPattern public methods
      var gMethodGroup = new GMethodGroup(gName: "Methods for ConsoleMonitor Pattern StateMachine states");
      var gMethod = new GMethod(new GMethodDeclaration(gName: "InitiateContactWithConsoleMonitor", gType: "void",
          gVisibility: "private", gAccessModifier: "", isConstructor: false,
          gArguments: new Dictionary<Philote<GArgument>, GArgument>()),
        new GBody(gStatements: new List<string>() {
          "ConsoleMonitor.RequestContact();",
          "StateMachine.Fire(Trigger.ConsoleMonitorRequestContactSent);"
        }),
        new GComment(new List<string>() {
          "// ",
        }));
      gMethodGroup.GMethods[gMethod.Philote] = gMethod;


      gMethod = new GMethod(new GMethodDeclaration(gName: "AcknowledgeConsoleMonitorContact", gType: "void",
          gVisibility: "public", gAccessModifier: "", isConstructor: false,
          gArguments: new Dictionary<Philote<GArgument>, GArgument>()),
        new GBody(gStatements: new List<string>() { "// Called By Console Monitor",
          "// Just move to the next state", "StateMachine.Fire(Trigger.ConsoleMonitorRequestContactAcknowledgementReceived);" }),
        new GComment(new List<string>() {
          "// ",
        }));

      gMethod = new GMethod(new GMethodDeclaration(gName: "SubscribeToConsoleMonitor", gType: "void",
          gVisibility: "public", gAccessModifier: "", isConstructor: false,
          gArguments: new Dictionary<Philote<GArgument>, GArgument>()),
        new GBody(gStatements: new List<string>() { "// Called By ConsoleMonitor",
          "// Subscribe to ConsoleMonitor's ISObservable",
          "StateMachine.Fire(Trigger.SubscribeToConsoleMonitorReceived);" }),
        new GComment(new List<string>() {
          "// Called By ConsoleMonitor",
        }));
      #endregion
      return gMethodGroup;
    }

    public static void MConsoleMonitorClientInterface(GAssemblyUnit gAssemblyUnit, GCompilationUnit gCompilationUnit,
      GNamespace gNamespace, GInterface gInterface, string baseNamespace) {
      #region Interface Assembly Unit
      //#region UsingGroup
      var gUsingGroup = MUsingGroupForConsoleMonitorPatternInInterfaces();
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);

      //#endregion
      //#region PropertyGroup ForConsoleMonitorPattern
      //MPropertyGroupForConsoleMonitorPattern(gClass);
      //#endregion
      //#region Injected PropertyGroup ForConsoleMonitorPattern
      //MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedConsoleMonitorService(gClass, gConstructor);
      //#endregion
      //#region MethodGroup ForConsoleMonitorPattern
      //MMethodGroupForConsoleMonitorPattern(gClass);
      //#endregion
      #region ItemGroups for the ProjectUnit For ConsoleMonitorPattern
      MReferenceItemGroupInInterfaceProjectUnitForConsoleMonitorService(gAssemblyUnit);
      #endregion
      #endregion
    }


  }
}
