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
    public static void MConsoleMonitorClient(GAssemblyGroup gAssemblyGroup, string baseNamespace) {
      #region Base Assembly Unit
      // Get the namespace, and class, to which the gEnumerationGroup and GStaticVariable will be added
      GAssemblyUnit gAssemblyUnit = default;
      GCompilationUnit gCompilationUnit = default;
      GNamespace gNamespace = default;
      GClass gClass = default;
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
      MConsoleMonitorClientBase(gAssemblyUnit, gCompilationUnit, gNamespace, gClass, gConstructor, baseNamespace);
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
      MConsoleMonitorClientInterface(gAssemblyUnit, gCompilationUnit, gNamespace, gInterface, baseNamespace);
      #endregion
    }
    public static void MConsoleMonitorClientBase(GAssemblyUnit gAssemblyUnit, GCompilationUnit gCompilationUnit,
      GNamespace gNamespace, GClass gClass, GMethod gConstructor, string baseNamespace) {
      #region Base ASsembly Unit
      #region UsingGroup
      MUsingsForConsoleMonitorPattern(gCompilationUnit, baseNamespace);
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
      MProjectReferenceItemGroupInBaseProjectUnitForConsoleMonitorService(gAssemblyUnit);
      #endregion
      #endregion
    }
    public static void MConsoleMonitorClientInterface(GAssemblyUnit gAssemblyUnit, GCompilationUnit gCompilationUnit,
        GNamespace gNamespace, GInterface gInterface, string baseNamespace) {
      #region Interface Assembly Unit
      //#region UsingGroup
      //MUsingsForConsoleMonitorPattern(gCompilationUnit, baseNamespace);
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
      MProjectReferenceItemGroupInInterfaceProjectUnitForConsoleMonitorService(gAssemblyUnit);
      #endregion
      #endregion
    }

    public static void MUsingsForConsoleMonitorPattern(GCompilationUnit gCompilationUnit, string baseNamespace) {
      var gUsingGroup = new GUsingGroup("Usings For ConsoleMonitor Pattern").AddUsing(new List<GUsing>() {
        new GUsing($"{baseNamespace}.ConsoleMonitor"),
      });
      gCompilationUnit.GUsingGroups[gUsingGroup.Philote] = gUsingGroup;
    }
    public static void MPropertyGroupForConsoleMonitorPattern(GClass gClass) {
      var gPropertyGroup = new GPropertyGroup("Propertys needed to interoperate with the ConsoleMonitor Service");
      foreach (var o in new List<GProperty>() {
        new GProperty("SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle", gType: "IDisposable",
          gAccessors: "{ get; set; }", gVisibility: "protected internal"),
        // new GProperty("Choices", gType: "Dictionary<String,IEnumerable<string>>", gAccessors: "{ get; }", gVisibility: "protected internal"),
      }) {
        gPropertyGroup.GPropertys[o.Philote] = o;
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
      GMethod gMethod = CreateWriteAsyncMethod();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      gMethod = MBuildMenuMethodForConsoleMonitorPatter();
      gMethodGroup.GMethods.Add(gMethod.Philote, gMethod);
      //gMethod = new GMethod().CreateReadCharMethod();
      //newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gClass.AddMethodGroup(gMethodGroup);
    }
    public static void
      MProjectReferenceItemGroupInBaseProjectUnitForConsoleMonitorService(GAssemblyUnit gAssemblyUnit) {

      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ReferencesUsedByConsoleMonitorServiceClients",
        "Packages referenced by Clients wishing to use the GHConsoleMonitorService", new GBody(new List<string>() {
          "<PackageReference Include=\"ConsoleMonitor.Interfaces\" />",
          "<PackageReference Include=\"ConsoleMonitor\" />",
        }));
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gItemGroupInProjectUnit.Philote,
        gItemGroupInProjectUnit);
    }
    public static void
      MProjectReferenceItemGroupInInterfaceProjectUnitForConsoleMonitorService(GAssemblyUnit gAssemblyUnit) {

      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ReferencesUsedByConsoleMonitorServiceClients",
        "Packages referenced by Clients wishing to use the GHConsoleMonitorService", new GBody(new List<string>() {
          "<PackageReference Include=\"ConsoleMonitor.Interfaces\" />",
        }));
      gAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(gItemGroupInProjectUnit.Philote,
        gItemGroupInProjectUnit);
    }

    public static GMethod MBuildMenuMethodForConsoleMonitorPatter() {
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in new List<GArgument>() {
        new GArgument("mesg","StringBuilder"),
        new GArgument("choices","IEnumerable<string>"),
        new GArgument("cancellationToken","CancellationToken?")
      }) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "SubscribeToConsoleReadLine", gType: "IDisposable",
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


    public static GMethod CreateReadLineMethod() {
      var gMethodArgumentList = new List<GArgument>() {
        new GArgument("inService","TypeOfHostedservice"),
        //new GArgument("mesg","string"),
        new GArgument("ct","CancellationToken?")
      };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "SubscribeToConsoleReadLine", gType: "IDisposable",
          gVisibility: "private", gAccessModifier: "", isConstructor: false,
          gArguments: gMethodArguments),
        gBody:
        new GBody(new List<string>() {
          "return Task.CompletedTask;"
        }),
        new GComment(new List<string>() {
          "// Used to write a string to the consoleout service"
        }));
    }


  }
}
