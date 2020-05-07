using System.Collections.Generic;

using ATAP.Utilities.Philote;
using static GenerateProgram.GMethodExtensions;

namespace GenerateProgram {
  public static partial class GMethodGroupExtensions {
    public static GMethodGroup CreateStartStopAsyncMethods() {
      GMethodGroup newgMethodGroup =
        new GMethodGroup(gName: "Start and Stop Async Methods for IHostedService (part of Generic Host)");
      GMethod gMethod = new GMethod().CreateStartAsyncMethod();
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gMethod = new GMethod().CreateStopAsyncMethod();
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      return newgMethodGroup;
    }
    public static GMethodGroup CreateHostApplicationLifetimeEventHandlerMethods() {
      GMethodGroup newgMethodGroup =
        new GMethodGroup(gName: "OnStarted, OnStopping, and OnStopped Event Handler Methods for HostApplicationLifetime events");
      GMethod gMethod = CreateOnStartedMethod();
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gMethod = CreateOnStoppingMethod();
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gMethod = CreateOnStoppedMethod();
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      return newgMethodGroup;
    }
    public static GMethodGroup CreateUsesConsoleMonitorMethods() {
      GMethodGroup gMethodGroup =
        new GMethodGroup(gName: " Methods for GenericHostHostedServices that use the ConsoleMonitor convention for handling input and output");
      GMethod gMethod = CreateWriteAsyncMethod();
      gMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gMethod = CreateBuildMenuMethod();
      gMethodGroup.GMethods[gMethod.Philote] = gMethod;
      //gMethod = new GMethod().CreateReadCharMethod();
      //newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      return gMethodGroup;
    }
  }
}
