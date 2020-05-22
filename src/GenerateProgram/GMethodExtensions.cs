using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class GMethodExtensions {
    public static GMethod CreateStartAsyncMethod( string gAccessModifier = "") {
      var gMethodDeclaration = new GMethodDeclaration(gName: "StartAsync", gType: "Task",
        gVisibility: "public", gAccessModifier: gAccessModifier, isConstructor: false,
        gArguments: new Dictionary<Philote<GArgument>, GArgument>());
      foreach (var kvp in new Dictionary<string, string>() { { "genericHostsCancellationToken", "CancellationToken " } }) {
        var gMethodArgument = new GArgument(kvp.Key, kvp.Value);
        gMethodDeclaration.GArguments[gMethodArgument.Philote] = gMethodArgument;
      }

      var gBody = new GBody(gStatements: new List<string>() {
        "#region create linkedCancellationSource and token",
        "  // Combine the cancellation tokens,so that either can stop this HostedService",
        "  //linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);",
        "  //GenericHostsCancellationToken = genericHostsCancellationToken;",
        " #endregion",
        " #region Register actions with the CancellationToken (s)",
        "  //GenericHostsCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer[\"{0} {1} GenericHostsCancellationToken has signalled stopping.\"], \"FileSystemToObjectGraphService\", \"StartAsync\"));",
        "  //internalCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer[\"{0} {1} internalCancellationToken has signalled stopping.\"], \"FileSystemToObjectGraphService\", \"internalCancellationToken\"));",
        "  //linkedCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer[\"{0} {1} GenericHostsCancellationToken has signalled stopping.\"], \"FileSystemToObjectGraphService\",\"GenericHostsCancellationToken\"));",
        "#endregion",
        "#region register local event handlers with the IHostApplicationLifetime's events",
        "  // Register the methods defined in this class with the three CancellationToken properties found on the IHostApplicationLifetime instance passed to this class in it's .ctor",
        "  HostApplicationLifetime.ApplicationStarted.Register(OnStarted);",
        "  HostApplicationLifetime.ApplicationStopping.Register(OnStopping);",
        "  HostApplicationLifetime.ApplicationStopped.Register(OnStopped);",
        "#endregion",
        "DataInitializationInStartAsyncReplacementPattern",
        "//return Task.CompletedTask;"
      });

      GComment gComment = new GComment(new List<string>() { });
      GMethod newgMethod = new GMethod(gMethodDeclaration, gBody, gComment);
      return newgMethod;
    }

    public static GMethod CreateStopAsyncMethod(string gAccessModifier = "") {
      var gMethodDeclaration = new GMethodDeclaration(gName: "StopAsync", gType: "Task",
        gVisibility: "public", gAccessModifier: gAccessModifier,  isConstructor: false,
        gArguments: new Dictionary<Philote<GArgument>, GArgument>());
      foreach (var kvp in new Dictionary<string, string>() { { "genericHostsCancellationToken", "CancellationToken " } }) {
        var gMethodArgument = new GArgument(kvp.Key, kvp.Value);
        gMethodDeclaration.GArguments[gMethodArgument.Philote] = gMethodArgument;
      }

      var gBody = new GBody(gStatements:new List<string>() {
        "// StopAsync issued in both IHostedService and IHostLifetime interfaces",
        "// This IS called when the user closes the ConsoleWindow with the windows top right pane \"x (close)\" icon",
        "// This IS called when the user hits ctrl-C in the console window",
        "//  After Ctrl-C and after this method exits, the Debugger",
        "//   shows an unhandled Exception: System.OperationCanceledException: 'The operation was canceled.'",
        "// See also discussion of Stop async in the following attributions.",
        "// Attribution to  https://stackoverflow.com/questions/51044781/graceful-shutdown-with-generic-host-in-net-core-2-1",
        "// Attribution to https://stackoverflow.com/questions/52915015/how-to-apply-hostoptions-shutdowntimeout-when-configuring-net-core-generic-host for OperationCanceledException notes",
        //Not sure if this is the right place for the dispose
        "DataDisposalInStopAsyncReplacemenmtPattern",
        "//InternalCancellationTokenSource.Cancel();",
        "// Defer completion promise, until our application has reported it is done.",
        "// return TaskCompletionSource.Task;",
        "//Stop(); // would call the servicebase stop if this was a generic hosted service ??",
        "//return Task.CompletedTask;"
      });
      GComment gComment = new GComment(new List<string>() { });
      return new GMethod(gMethodDeclaration, gBody, gComment);
    }

    public static GMethod CreateExecuteAsyncMethod(string gAccessModifier = "") {
      var gMethodDeclaration = new GMethodDeclaration(gName: "ExecuteAsync", gType: "Task",
        gVisibility: "protected", gAccessModifier: gAccessModifier, isConstructor: false,
        gArguments: new Dictionary<Philote<GArgument>, GArgument>());
      foreach (var kvp in new Dictionary<string, string>() { { "genericHostsCancellationToken", "CancellationToken " } }) {
        var gMethodArgument = new GArgument(kvp.Key, kvp.Value);
        gMethodDeclaration.GArguments[gMethodArgument.Philote] = gMethodArgument;
      }

      var gBody = new GBody(gStatements: new List<string>() {
        "#region create linkedCancellationSource and token",
        "// Combine the cancellation tokens,so that either can stop this HostedService",
        "//linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);",
        "//var linkedCancellationToken = linkedCancellationTokenSource.Token;",
        "#endregion",
        "#region Register actions with the CancellationToken (s)",
        "//externalCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer[\"{0} {1} externalCancellationToken has signalled stopping.\"], \"ConsoleMonitorBackgroundService\", \"externalCancellationToken\"));",
        "//internalCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer[\"{0} {1} internalCancellationToken has signalled stopping.\"], \"ConsoleMonitorBackgroundService\", \"internalCancellationToken\"));",
        "//linkedCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer[\"{0} {1} linkedCancellationToken has signalled stopping.\"], \"ConsoleMonitorBackgroundService\", \"linkedCancellationToken\"));",
        "#endregion",
        "#region Instantiate this service's Data structure",
        "DataInitializationInStartAsyncReplacementPattern",

        "#endregion",
        "// Wait for the conjoined cancellation token (or individually if the hosted service does not define its own internal cts)",
        "// WaitHandle.WaitAny(new[] { linkedCancellationToken.WaitHandle });",
        "Logger.LogDebug(DebugLocalizer[\"{0} {1} ConsoleMonitorBackgroundService is stopping due to \"], \"ConsoleMonitorBackgroundService\", \"ExecuteAsync\"); // add third parameter for internal or external",
        "AssemblyUnitNameReplacementPatternBaseData.Dispose();",

      });
      GComment gComment = new GComment(new List<string>() {
        "/// <summary>",
        "/// Called by the genericHost to start the Backgroundservice.",
        "/// Sets up data structures",
        "/// </summary>",
        "/// <param name=\"externalCancellationToken\"></param>",
        "/// <returns></returns>",
      });
      return new GMethod(gMethodDeclaration, gBody, gComment);
    }


    public static GMethod CreateOnStartedMethod() {
      var gMethodDeclaration = new GMethodDeclaration(gName: "OnStarted", gType: "void",
        gVisibility: "public", gAccessModifier: "virtual", isConstructor: false,
        gArguments: new Dictionary<Philote<GArgument>, GArgument>());
      return new GMethod(gMethodDeclaration,
        new GBody(gStatements:new List<string>() { "// Post-startup code goes here", }),
        new GComment(new List<string>() {
          "// Registered as a handler with the HostApplicationLifetime.ApplicationStarted event",
        }));
    }
    public static GMethod CreateOnStoppingMethod() {
      return new GMethod(
        new GMethodDeclaration(gName: "OnStopping", gType: "void",
          gVisibility: "public", gAccessModifier: "virtual", isConstructor: false,
          gArguments: new Dictionary<Philote<GArgument>, GArgument>()),
        new GBody(gStatements: new List<string>() { "// On-stopping code goes here", }),
        new GComment(new List<string>() {
          "// Registered as a handler with the HostApplicationLifetime.ApplicationStarted event",
        }));
    }
    public static GMethod CreateOnStoppedMethod() {
      return new GMethod(
        new GMethodDeclaration(gName: "OnStopped", gType: "void",
          gVisibility: "public", gAccessModifier: "virtual", isConstructor: false,
          gArguments: new Dictionary<Philote<GArgument>, GArgument>()),
        new GBody(gStatements: new List<string>() { "// On-stopped code goes here", }),
        new GComment(new List<string>() {
          "// Registered as a handler with the HostApplicationLifetime.ApplicationStarted event",
          "// This is NOT called if the ConsoleWindows ends when the connected browser (browser opened by LaunchSettings when starting with debugger) is closed (not applicable to ConsoleLifetime generic hosts)",
          "// This IS called if the user hits ctrl-C in the ConsoleWindow"
        }));
    }


  }
}
