using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class GMethodExtensions {
    public static GMethod CreateStartAsyncMethod( bool usesConsoleMonitorConvention = false) {
      var gMethodDeclaration = new GMethodDeclaration(gName: "StartAsync", gType: "Task",
        gVisibility: "public", gAccessModifier: "async", isConstructor: false,
        gArguments: new Dictionary<Philote<GArgument>, GArgument>());
      foreach (var kvp in new Dictionary<string, string>() { { "genericHostsCancellationToken", "CancellationToken " } }) {
        var gMethodArgument = new GArgument(kvp.Key, kvp.Value);
        gMethodDeclaration.GArguments[gMethodArgument.Philote] = gMethodArgument;
      }

      var gMethodBody = new GMethodBody(gStatementsList: new List<string>() {
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
        "// Wait to be connected to the stdIn observable",
        "//return Task.CompletedTask;"
      });

      GComment gComment = new GComment(new List<string>() { });
      GMethod newgMethod = new GMethod(gMethodDeclaration, gMethodBody, gComment);
      return newgMethod;
    }

    public static GMethod CreateStopAsyncMethod(bool usesConsoleMonitorConvention = false) {
      var gMethodDeclaration = new GMethodDeclaration(gName: "StopAsync", gType: "Task",
        gVisibility: "public", gAccessModifier: "async", isConstructor: false,
        gArguments: new Dictionary<Philote<GArgument>, GArgument>());
      foreach (var kvp in new Dictionary<string, string>() { { "genericHostsCancellationToken", "CancellationToken " } }) {
        var gMethodArgument = new GArgument(kvp.Key, kvp.Value);
        gMethodDeclaration.GArguments[gMethodArgument.Philote] = gMethodArgument;
      }

      var gMethodBody = new GMethodBody(gStatementsList:new List<string>() {
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
      return new GMethod(gMethodDeclaration, gMethodBody, gComment);
    }

    public static GMethod CreateExecuteAsyncMethod(bool usesConsoleMonitorConvention = false) {
      var gMethodDeclaration = new GMethodDeclaration(gName: "ExecuteAsync", gType: "Task",
        gVisibility: "protected", gAccessModifier: "override async", isConstructor: false,
        gArguments: new Dictionary<Philote<GArgument>, GArgument>());
      foreach (var kvp in new Dictionary<string, string>() { { "genericHostsCancellationToken", "CancellationToken " } }) {
        var gMethodArgument = new GArgument(kvp.Key, kvp.Value);
        gMethodDeclaration.GArguments[gMethodArgument.Philote] = gMethodArgument;
      }

      var gMethodBody = new GMethodBody(gStatementsList: new List<string>() {
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
        // Embedded object As Data 
        "AssemblyUnitNameReplacementPatternBaseData = new AssemblyUnitNameReplacementPatternBaseData();",
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
        "ConfigurationRoot = configurationBuilder.Build();",
        "#endregion",
        // Embedded object as Data 
        "AssemblyUnitNameReplacementPatternBaseData = new AssemblyUnitNameReplacementPatternBaseData();",
        "*/",
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
      return new GMethod(gMethodDeclaration, gMethodBody, gComment);
    }


    public static GMethod CreateOnStartedMethod() {
      var gMethodDeclaration = new GMethodDeclaration(gName: "OnStarted", gType: "void",
        gVisibility: "private", gAccessModifier: "", isConstructor: false,
        gArguments: new Dictionary<Philote<GArgument>, GArgument>());
      return new GMethod(gMethodDeclaration,
        new GMethodBody(gStatementsList:new List<string>() { "// Post-startup code goes here", }),
        new GComment(new List<string>() {
          "// Registered as a handler with the HostApplicationLifetime.ApplicationStarted event",
        }));
    }
    public static GMethod CreateOnStoppingMethod() {
      return new GMethod(
        new GMethodDeclaration(gName: "OnStopping", gType: "void",
          gVisibility: "private", gAccessModifier: "", isConstructor: false,
          gArguments: new Dictionary<Philote<GArgument>, GArgument>()),
        new GMethodBody(gStatementsList: new List<string>() { "// On-stopping code goes here", }),
        new GComment(new List<string>() {
          "// Registered as a handler with the HostApplicationLifetime.ApplicationStarted event",
        }));
    }
    public static GMethod CreateOnStoppedMethod() {
      return new GMethod(
        new GMethodDeclaration(gName: "OnStopped", gType: "void",
          gVisibility: "private", gAccessModifier: "", isConstructor: false,
          gArguments: new Dictionary<Philote<GArgument>, GArgument>()),
        new GMethodBody(gStatementsList: new List<string>() { "// On-stopped code goes here", }),
        new GComment(new List<string>() {
          "// Registered as a handler with the HostApplicationLifetime.ApplicationStarted event",
          "// This is NOT called if the ConsoleWindows ends when the connected browser (browser opened by LaunchSettings when starting with debugger) is closed (not applicable to ConsoleLifetime generic hosts)",
          "// This IS called if the user hits ctrl-C in the ConsoleWindow"
        }));
    }

    public static GMethod CreateWriteAsyncMethod() {
      var gMethodArgumentList = new List<GArgument>() {
        new GArgument("mesg","string"),
        new GArgument("ct","CancellationToken?")
      };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "WriteAsync", gType: "Task",
          gVisibility: "private", gAccessModifier: "async", isConstructor: false,
          gArguments: gMethodArguments),
        gBody:
        new GStatementList(new List<string>() {
          "ct?.ThrowIfCancellationRequested();",
          "var task = await ConsoleMonitorGenericHostHostedService.WriteMessageAsync(mesg).ConfigureAwait(false);",
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
        "return Task.CompletedTask;"
        }),
        new GComment(new List<string>() {
          "// Used to write a string to the consoleout service"
        }));
    }

    public static GMethod CreateBuildMenuMethod() {
      var gMethodArgumentList = new List<GArgument>() {
        new GArgument("Choices","TypeOfHostedservice"),
        new GArgument("mesg","StringBuilder"),
        new GArgument("choices","IEnumerable<string>"),
        new GArgument("cancellationToken","CancellationToken?")
      };
      var gMethodArguments = new Dictionary<Philote<GArgument>, GArgument>();
      foreach (var o in gMethodArgumentList) { gMethodArguments.Add(o.Philote, o); }

      return new GMethod(
        new GMethodDeclaration(gName: "SubscribeToConsoleReadLine", gType: "IDisposable",
          gVisibility: "private", gAccessModifier: "", isConstructor: false,
          gArguments: gMethodArguments),
        gBody:
        new GStatementList( new List<string>() {
          "cancellationToken?.ThrowIfCancellationRequested();",
          "mesg.Clear();",
          "foreach (var choice in choices) {",
          "mesg.Append(choice);",
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
        new GStatementList( new List<string>() {
          "return Task.CompletedTask;"
        }),
        new GComment(new List<string>() {
          "// Used to write a string to the consoleout service"
        }));
    }

  }
}
