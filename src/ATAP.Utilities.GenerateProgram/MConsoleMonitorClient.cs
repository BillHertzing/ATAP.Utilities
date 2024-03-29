using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static ATAP.Utilities.GenerateProgram.GAssemblyGroupExtensions;
using static ATAP.Utilities.GenerateProgram.StringConstants;
//using AutoMapper.Configuration;
using static ATAP.Utilities.GenerateProgram.GPropertyGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GMethodExtensions;
using static ATAP.Utilities.GenerateProgram.GMethodGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GUsingGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GAssemblyUnitExtensions;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GMacroExtensions {
    public static void MConsoleMonitorClient(GAssemblyGroup gAssemblyGroup, (
      IEnumerable<GAssemblyUnit> gAssemblyUnits,
      IEnumerable<GCompilationUnit> gCompilationUnits,
      IEnumerable<GNamespace> gNamespacess,
      IEnumerable<GClass> gClasss,
      IEnumerable<GMethod> gMethods) lookupResultsTuple, string baseNamespaceName = "", List<string> rawDiGraph = default,(GBody, GComment) gBodyCommentTuple = default ) {
      MConsoleMonitorClient(gAssemblyGroup, lookupResultsTuple.gAssemblyUnits.First(), lookupResultsTuple.gCompilationUnits.First(),
        lookupResultsTuple.gNamespacess.First(), lookupResultsTuple.gClasss.First(), lookupResultsTuple.gMethods.First(),
        baseNamespaceName:baseNamespaceName, rawDiGraph, gBodyCommentTuple);
    }
    public static void MConsoleMonitorClient(IGAssemblyGroup gAssemblyGroup, IGAssemblyUnit gAssemblyUnit = default, IGCompilationUnit gCompilationUnit = default,
      IGNamespace gNamespace = default, IGClass gClass = default, IGMethod gMethod = default,
      string baseNamespaceName = "",
      List<string> rawDiGraph = default,
        (IGBody, IGComment) gBodyCommentTuple = default
      ) {
      #region Titular Base Assembly Unit
      MConsoleMonitorClientBase(gAssemblyUnit, gCompilationUnit, gNamespace, gClass, gMethod, baseNamespaceName,rawDiGraph,gBodyCommentTuple);
    }

    #endregion

    public static void MConsoleMonitorClientBase(IGAssemblyUnit gAssemblyUnit, IGCompilationUnit gCompilationUnit,
      IGNamespace gNamespace, IGClass gClass, IGMethod gConstructor,
      string baseNamespaceName = "",
      IList<string> rawDiGraph = default,
      (IGBody, IGComment) gBodyCommentTuple = default
      ) {
      #region UsingGroup
      MUsingsForConsoleMonitorPattern(gCompilationUnit, baseNamespaceName);
      #endregion
      #region PropertyGroup For ConsoleMonitorPattern
      MPropertyGroupForConsoleMonitorPattern(gClass);
      #endregion
      #region Injected PropertyGroup For ConsoleMonitorPattern
      MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedConsoleMonitorGHS(gClass, gConstructor);
      #endregion
      #region MethodGroup For ConsoleMonitorPattern
      MMethodGroupForConsoleMonitorPattern(gClass, gBodyCommentTuple);
      #endregion
      #region DelegateGroup For ConsoleMonitorPattern
      MDelegateGroupForConsoleMonitorPattern(gClass);
      #endregion
      #region ItemGroups for the ProjectUnit For ConsoleMonitorPattern
      MReferenceItemGroupInBaseProjectUnitForConsoleMonitorGHS(gAssemblyUnit);
      #endregion
    }
    public static void MUsingsForConsoleMonitorPattern(IGCompilationUnit gCompilationUnit, string baseNamespace) {
      var gUsingGroup = new GUsingGroup("Usings For ConsoleMonitor Pattern").AddUsing(new List<IGUsing>() {
        new GUsing($"{baseNamespace}.ConsoleMonitorGHS"),
        new GUsing("System.Text"),
      });
      gCompilationUnit.GUsingGroups.Add(gUsingGroup.Philote, gUsingGroup);
    }
    public static void MPropertyGroupForConsoleMonitorPattern(IGClass gClass) {
      var gPropertyGroup = new GPropertyGroup("Propertys needed to interoperate with the ConsoleMonitorGHS Service");
      foreach (var o in new List<IGProperty>() {
        new GProperty("SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle", gType: "IDisposable",
          gAccessors: "{ get; set; }", gVisibility: "protected internal"),
        // new GProperty("Choices", gType: "Dictionary<String,IEnumerable<string>>", gAccessors: "{ get; }", gVisibility: "protected internal"),
      }) {
        gPropertyGroup.GPropertys.Add(o.Philote, o);
      }
      gClass.AddPropertyGroups(gPropertyGroup);
    }
    public static void MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedConsoleMonitorGHS(IGClass gClass,
      IGMethod gConstructor) {
      var gPropertyGroup = new GPropertyGroup("Injected Property for ConsoleMonitorGHS");
      gClass.AddPropertyGroups(gPropertyGroup);
      foreach (var o in new List<string>() { "ConsoleMonitorGHS" }) {
        gClass.AddTConstructorAutoPropertyGroup(gConstructor.Philote, o, gPropertyGroupId: gPropertyGroup.Philote);
      }
    }
    public static void MMethodGroupForConsoleMonitorPattern(IGClass gClass, (IGBody, IGComment) gBodyCommentTuple = default) {
      var gMethodGroup =
        new GMethodGroup(gName: "MethodGroup For ConsoleMonitorPattern");
      //GMethod gMethod = MCreateWriteAsyncMethodForConsoleMonitorPattern();
      //gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      var gMethod = MCreateWriteMethodForConsoleMonitorPattern();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      gMethod = MBuildMenuMethodForConsoleMonitorPattern();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      //gMethod = new GMethod().CreateReadCharMethod();
      //gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      gMethod = MCreateReadLineMethodForConsoleMonitorPattern();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      gMethod = MCreateProcessInputStringMethodForConsoleMonitorPattern(gBodyCommentTuple);
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      gClass.AddMethodGroup(gMethodGroup);
      gClass.AddMethodGroup(MCreateStateTransitionMethodGroupForConsoleMonitorPattern());
    }
    public static void MDelegateGroupForConsoleMonitorPattern(IGClass gClass) {
      var gDelegateGroup =
        new GDelegateGroup(gName: "DelegateGroup For ConsoleMonitorPattern");
      gClass.AddDelegateGroup(MCreateStateTransitionDelegateGroupForConsoleMonitorPattern());
    }
    public static void
      MReferenceItemGroupInBaseProjectUnitForConsoleMonitorGHS(IGAssemblyUnit gAssemblyUnit) {

      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ReferencesUsedByConsoleMonitorGHSClients",
        "Packages referenced by Clients wishing to use the ConsoleMonitorGHS", new GBody(new List<string>() {
          "<PackageReference Include=\"ConsoleMonitorGHS.Interfaces\" />",
          "<PackageReference Include=\"ConsoleMonitorGHS\" />",
        }));
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gItemGroupInProjectUnit.Philote,
        gItemGroupInProjectUnit);
    }
    public static void
      MReferenceItemGroupInInterfaceProjectUnitForConsoleMonitorGHS(IGAssemblyUnit gAssemblyUnit) {

      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ReferencesUsedByConsoleMonitorGHSClients",
        "Packages referenced by Clients wishing to use the GHConsoleMonitorGHS", new GBody(new List<string>() {
          "<PackageReference Include=\"ConsoleMonitorGHS.Interfaces\" />",
        }));
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gItemGroupInProjectUnit.Philote,
        gItemGroupInProjectUnit);
    }

    public static IGMethod MBuildMenuMethodForConsoleMonitorPattern() {
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
      foreach (var o in new List<IGArgument>() {
        new GArgument("mesg","StringBuilder"),
        new GArgument("choices","IEnumerable<string>"),
        new GArgument("cancellationToken","CancellationTokenFromCaller?")
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
    public static IGMethod MCreateReadLineMethodForConsoleMonitorPattern() {
      var gMethodArgumentList = new List<IGArgument>() {
        new GArgument("ct","CancellationTokenFromCaller?")
      };
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
      foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "SubscribeToConsoleMonitorReadLineAsyncAsObservable", gType: "IDisposable",
          gVisibility: "private", gAccessModifier: "async", isConstructor: false,
          gArguments: gMethodArguments),
        gBody:
        new GBody(new List<string>() {
          "return ConsoleMonitorGHS.ConsoleReadLineAsyncAsObservable().Subscribe(",
          "() => ProcessInput(inputString, ct)",
          ");",
        }),
        new GComment(new List<string>() {
          "// Subscribes to the ConsoleMonitorGHS  Todo: finish this comment"
        }));
    }

    public static IGMethod MCreateProcessInputStringMethodForConsoleMonitorPattern(
      (IGBody gBody, IGComment gComment) gBodyCommentTuple = default) {
      var gMethodArgumentList = new List<IGArgument>() {
        new GArgument("inputString", "string"), new GArgument("ct", "CancellationTokenFromCaller?"),
      };
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
      foreach (var o in gMethodArgumentList) {
        gMethodArguments.Add(o.Philote, o);
      }

      return new GMethod(
        new GMethodDeclaration(gName: "ProcessInput", gType: "void",
          gVisibility: "", gAccessModifier: "", isConstructor: false,
          gArguments: gMethodArguments),
        gBody: gBodyCommentTuple.gBody,
        gComment: gBodyCommentTuple.gComment
      );
    }

    public static IGMethod MCreateWriteAsyncMethodForConsoleMonitorPattern(string gAccessModifier = "") {
      var gMethodArgumentList = new List<IGArgument>() {
    new GArgument("mesg","string"),
    new GArgument("ct","CancellationTokenFromCaller?")
  };
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
      foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "WriteAsync", gType: "Task",
          gVisibility: "private", gAccessModifier: gAccessModifier + " async", isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            "StateMachine.Fire(Trigger.WriteAsyncStarted);",
        "ct?.ThrowIfCancellationRequested();",
        "var task = await ConsoleMonitorGHS.WriteAsync(mesg, ct).ConfigureAwait(false);",
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
      "// Used to write a string to the ConsoleMonitorGHS"
        }));
    }

    static IGMethod MCreateWriteMethodForConsoleMonitorPattern(string gAccessModifier = "") {
      var gMethodArgumentList = new List<IGArgument>() {
        new GArgument("mesg","string"),
        new GArgument("ct","CancellationTokenFromCaller?")
      };
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
      foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "Write", gType: "void",
          gVisibility: "private", gAccessModifier: gAccessModifier, isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            "StateMachine.Fire(Trigger.WriteStarted);",
            "ct?.ThrowIfCancellationRequested();",
            "ConsoleMonitorGHS.Write(mesg, ct);",
            "StateMachine.Fire(Trigger.WriteFinished);",
          }),
        new GComment(new List<string>() {
          "// Used to write a string to Write method of the ConsoleMonitorGHS"
        }));
    }

    static IGMethod MCreateInitiateContactWithConsoleMonitorMethodForConsoleMonitorPattern(string gAccessModifier = "") {
      var gMethodArgumentList = new List<IGArgument>() {
        new GArgument("ct","CancellationTokenFromCaller?")
      };
      var gMethodArguments = new Dictionary<IPhilote<IGArgument>, IGArgument>();
      foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "InitiateContactWithConsoleMonitor", gType: "void",
          gVisibility: "private", gAccessModifier: gAccessModifier, isConstructor: false,
          gArguments: gMethodArguments),
        gBody: new GBody(gStatements:
          new List<string>() {
            "ct?.ThrowIfCancellationRequested();",
            "ConsoleMonitorGHS.RequestContact();",
            "StateMachine.Fire(Trigger.ConsoleMonitorRequestContactSent);",
          }),
        new GComment(new List<string>() {
          "// Used to initiate a contact handshake with a ConsoleMonitorGHS"
        }));
    }

    public static IGMethodGroup MCreateStateTransitionMethodGroupForConsoleMonitorPattern() {
      #region ConsoleMonitorPattern public methods
      var gMethodGroup = new GMethodGroup(gName: "Methods for ConsoleMonitorPattern StateMachine states");
      var gMethod = new GMethod(new GMethodDeclaration(gName: "InitiateContactWithConsoleMonitor", gType: "void",
          gVisibility: "private", gAccessModifier: "", isConstructor: false,
          gArguments: new Dictionary<IPhilote<IGArgument>, IGArgument>()),
        new GBody(gStatements: new List<string>() {

          "StateMachine.Fire(Trigger.ConsoleMonitorRequestContactSent);"
        }),
        new GComment(new List<string>() {
          "// ",
        }));
      gMethodGroup.GMethods.Add(gMethod.Philote,gMethod);


      gMethod = new GMethod(new GMethodDeclaration(gName: "AcknowledgeConsoleMonitorContact", gType: "void",
          gVisibility: "public", gAccessModifier: "", isConstructor: false,
          gArguments: new Dictionary<IPhilote<IGArgument>, IGArgument>()),
        new GBody(gStatements: new List<string>() { "// Called By Console Monitor",
          "// Just move to the next state",
          "StateMachine.Fire(Trigger.ConsoleMonitorRequestContactAcknowledgementReceived);" }),
        new GComment(new List<string>() {
          "// ",
        }));

      gMethod = new GMethod(new GMethodDeclaration(gName: "SubscribeToConsoleMonitor", gType: "void",
          gVisibility: "public", gAccessModifier: "", isConstructor: false,
          gArguments: new Dictionary<IPhilote<IGArgument>, IGArgument>()),
        new GBody(gStatements: new List<string>() {
          "// Called By ConsoleMonitor",
          "// Subscribe to ConsoleMonitor's ISObservable",
          "StateMachine.Fire(Trigger.SubscribeToConsoleMonitorReceived);" }),
        new GComment(new List<string>() {
          "// Called By ConsoleMonitor",
        }));
      #endregion
      return gMethodGroup;
    }

    public static IGDelegateGroup MCreateStateTransitionDelegateGroupForConsoleMonitorPattern() {
      #region ConsoleMonitorPattern public methods
      var gDelegateGroup = new GDelegateGroup(gName: "Delegates for ConsoleMonitor Pattern states");
      var gDelegate = new GDelegate(new GDelegateDeclaration(gName: "ProcessInput", gType: "void",
          gVisibility: "private",
          gArguments: new Dictionary<IPhilote<IGArgument>, IGArgument>() ),
        new GComment(new List<string>() {
          "//  Delegate for the method that will process each input line ",
        }));
      foreach (var o in new List<IGArgument>() {
        new GArgument("inputString","string"),
        new GArgument("ct","CancellationTokenFromCaller?"),
      }) { gDelegate.GDelegateDeclaration.GArguments.Add(o.Philote, o); }
      gDelegateGroup.GDelegates.Add(gDelegate.Philote,gDelegate);

      #endregion
      return gDelegateGroup;
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
      //MPropertyGroupAndConstructorDeclarationAndInitializationForInjectedConsoleMonitorGHS(gClass, gConstructor);
      //#endregion
      //#region MethodGroup ForConsoleMonitorPattern
      //MMethodGroupForConsoleMonitorPattern(gClass);
      //#endregion
      #region ItemGroups for the ProjectUnit For ConsoleMonitorPattern
      MReferenceItemGroupInInterfaceProjectUnitForConsoleMonitorGHS(gAssemblyUnit);
      #endregion
      #endregion
    }


  }
}
