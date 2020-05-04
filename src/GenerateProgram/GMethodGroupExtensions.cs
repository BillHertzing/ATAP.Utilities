using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class GMethodGroupExtensions {
    public static GMethodGroup CreateStartStopAsyncMethods(this GMethodGroup gGMethodGroup) {
      GMethodGroup newgMethodGroup =
        new GMethodGroup(gName: "Start and Stop Async Methods for IHostedService (part of Generic Host)");
      GMethod gMethod = new GMethod().CreateStartAsyncMethod();
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gMethod = new GMethod().CreateStopAsyncMethod();
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      return newgMethodGroup;
    }
    public static GMethodGroup CreateHostApplicationLifetimeEventHandlerMethods(this GMethodGroup gGMethodGroup) {
      GMethodGroup newgMethodGroup =
        new GMethodGroup(gName: "OnStarted, OnStopping, and OnStopped Event Handler Methods for HostApplicationLifetime events");
      GMethod gMethod = new GMethod().CreateOnStartedMethod();
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gMethod = new GMethod().CreateOnStoppingMethod();
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      gMethod = new GMethod().CreateOnStoppedMethod();
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      return newgMethodGroup;
    }
  }
}
