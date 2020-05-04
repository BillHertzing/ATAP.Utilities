using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class GMethodExtensions {
    public static GMethod CreateStartAsyncMethod(this GMethod gGMethod) {
      var gMethodDeclaration = new GMethodDeclaration(gName: "StartAsync", gType: "Task",
        gVisibility: "public", gAccessModifier: "async", isConstructor: false,
        gMethodArguments: new Dictionary<Philote<GMethodArgument>, GMethodArgument>());
      foreach (var kvp in new Dictionary<string, string>() { { "genericHostsCancellationToken", "CancellationToken " } }) {
        var gMethodArgument = new GMethodArgument(kvp.Key, kvp.Value);
        gMethodDeclaration.GMethodArguments[gMethodArgument.Philote] = gMethodArgument;
      }

      var gMethodBody = new GMethodBody(statementList: new List<string>() {
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
        "// Wait to be connected to the stdIn observable",
        "//return Task.CompletedTask;"
      });

      GComment gComment = new GComment(new List<string>() { });
      GMethod newgMethod = new GMethod(gMethodDeclaration, gMethodBody, gComment);
      return newgMethod;
    }

    public static GMethod CreateStopAsyncMethod(this GMethod gGMethod) {
      var gMethodDeclaration = new GMethodDeclaration(gName: "StopAsync", gType: "Task",
        gVisibility: "public", gAccessModifier: "async", isConstructor: false,
        gMethodArguments: new Dictionary<Philote<GMethodArgument>, GMethodArgument>());
      foreach (var kvp in new Dictionary<string, string>() { { "genericHostsCancellationToken", "CancellationToken " } }) {
        var gMethodArgument = new GMethodArgument(kvp.Key, kvp.Value);
        gMethodDeclaration.GMethodArguments[gMethodArgument.Philote] = gMethodArgument;
      }

      var gMethodBody = new GMethodBody(statementList: new List<string>() {
        "// StopAsync issued in both IHostedService and IHostLifetime interfaces",
        "// This IS called when the user closes the ConsoleWindow with the windows top right pane \"x (close)\" icon",
        "// This IS called when the user hits ctrl-C in the console window",
        "//  After Ctrl-C and after this method exits, the Debugger",
        "//   shows an unhandled Exception: System.OperationCanceledException: 'The operation was canceled.'",
        "// See also discussion of Stop async in the following attributions.",
        "// Attribution to  https://stackoverflow.com/questions/51044781/graceful-shutdown-with-generic-host-in-net-core-2-1",
        "// Attribution to https://stackoverflow.com/questions/52915015/how-to-apply-hostoptions-shutdowntimeout-when-configuring-net-core-generic-host for OperationCanceledException notes",
        "//InternalCancellationTokenSource.Cancel();",
        "// Defer completion promise, until our application has reported it is done.",
        "// return TaskCompletionSource.Task;",
        "//Stop(); // would call the servicebase stop if this was a generic hosted service ??",
        "//return Task.CompletedTask;"
      });
      GComment gComment = new GComment(new List<string>() { });
      return new GMethod(gMethodDeclaration, gMethodBody, gComment);
    }

    public static GMethod CreateExecuteAsyncMethod(this GMethod gGMethod) {
      var gMethodDeclaration = new GMethodDeclaration(gName: "ExecuteAsync", gType: "Task",
        gVisibility: "protected", gAccessModifier: "override async", isConstructor: false,
        gMethodArguments: new Dictionary<Philote<GMethodArgument>, GMethodArgument>());
      foreach (var kvp in new Dictionary<string, string>() { { "genericHostsCancellationToken", "CancellationToken " } }) {
        var gMethodArgument = new GMethodArgument(kvp.Key, kvp.Value);
        gMethodDeclaration.GMethodArguments[gMethodArgument.Philote] = gMethodArgument;
      }

      var gMethodBody = new GMethodBody(statementList: new List<string>() {
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
        "/*",
        "#region configurationRoot for this HostedService",
        "// Create the configurationBuilder for this HostedService. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.",
        "// The Environment has been configured by the GenericHost before this point is reached",
        "// InitialStartupDirectory has been set by the GenericHost before this point is reached, and is where the GenericHost program or service was started",
        "// LoadedFromDirectory has been configured by the GenericHost before this point is reached. It is the location where this assembly resides",
        "// ToDo: Implement these two values into the GenericHost configurationRoot somehow, then remove from the constructor signature",
        "var loadedFromDirectory = hostConfiguration.GetValue<string>(\"SomeStringConstantConfigrootKey\", \"./\"); //ToDo suport dynamic assembly loading form other Startup directories -  Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);",
        "var initialStartupDirectory = hostConfiguration.GetValue<string>(\"SomeStringConstantConfigrootKey\", \"./\");",
        "// Build the configurationRoot for this service",
        "var configurationBuilder = ConfigurationExtensions.StandardConfigurationBuilder(loadedFromDirectory, initialStartupDirectory, ConsoleMonitorDefaultConfiguration.Production, ConsoleMonitorStringConstants.SettingsFileName, ConsoleMonitorStringConstants.SettingsFileNameSuffix, StringConstants.CustomEnvironmentVariablePrefix, LoggerFactory, stringLocalizerFactory, hostEnvironment, hostConfiguration, linkedCancellationToken);",
        "configurationRoot = configurationBuilder.Build();",
        "#endregion",
        "*/",
        "#endregion",
        "// Wait for the conjoined cancellation token (or individually if the hosted service does not define its own internal cts)",
        "// WaitHandle.WaitAny(new[] { linkedCancellationToken.WaitHandle });",
        "Logger.LogDebug(DebugLocalizer[\"{0} {1} ConsoleMonitorBackgroundService is stopping due to \"], \"ConsoleMonitorBackgroundService\", \"ExecuteAsync\"); // add third parameter for internal or external",
        "SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();",

      });
      GComment gComment = new GComment(new List<string>() {
        "/// <summary>",
        "/// Called by the genericHost to start the Backgroundservice.",
        "/// Sets up data structures",
        "/// </summary>",
        "/// <param name=\"externalCancellationToken\"></param>",
        "/// <returns></returns>",
      });
      return new GMethod(gMethodDeclaration, gMethodBody, gComment);
    }

    public static GMethod CreateOnStartedMethod(this GMethod gGMethod) {
      var gMethodDeclaration = new GMethodDeclaration(gName: "OnStarted", gType: "void",
        gVisibility: "private", gAccessModifier: "", isConstructor: false,
        gMethodArguments: new Dictionary<Philote<GMethodArgument>, GMethodArgument>());
      return new GMethod(gMethodDeclaration,
        new GMethodBody(statementList: new List<string>() { "// Post-startup code goes here", }),
        new GComment(new List<string>() {
          "// Registered as a handler with the HostApplicationLifetime.ApplicationStarted event",
        }));
    }
    public static GMethod CreateOnStoppingMethod(this GMethod gGMethod) {
      return new GMethod(
        new GMethodDeclaration(gName: "OnStopping", gType: "void",
          gVisibility: "private", gAccessModifier: "", isConstructor: false,
          gMethodArguments: new Dictionary<Philote<GMethodArgument>, GMethodArgument>()),
        new GMethodBody(statementList: new List<string>() { "// On-stopping code goes here", }),
        new GComment(new List<string>() {
          "// Registered as a handler with the HostApplicationLifetime.ApplicationStarted event",
        }));
    }
    public static GMethod CreateOnStoppedMethod(this GMethod gGMethod) {
      return new GMethod(
        new GMethodDeclaration(gName: "OnStopped", gType: "void",
          gVisibility: "private", gAccessModifier: "", isConstructor: false,
          gMethodArguments: new Dictionary<Philote<GMethodArgument>, GMethodArgument>()),
        new GMethodBody(statementList: new List<string>() { "// On-stopped code goes here", }),
        new GComment(new List<string>() {
          "// Registered as a handler with the HostApplicationLifetime.ApplicationStarted event",
          "// This is NOT called if the ConsoleWindows ends when the connected browser (browser opened by LaunchSettings when starting with debugger) is closed (not applicable to ConsoleLifetime generic hosts)",
          "// This IS called if the user hits ctrl-C in the ConsoleWindow"
        }));
    }
  }
}
