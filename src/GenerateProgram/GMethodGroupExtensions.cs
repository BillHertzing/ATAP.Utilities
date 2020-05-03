using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class GMethodGroupExtensions {
    public static GMethodGroup CreateStartStopAsyncMethods(this GMethodGroup gGMethodGroup) {
      GMethodDeclaration gMethodDeclaration = new GMethodDeclaration(gName: "StartAsync", gType: "void",
        gVisibility: "public", gAccessModifier: "async", isConstructor: false,
        gMethodArguments: new Dictionary<Philote<GMethodArgument>, GMethodArgument>());
      foreach (var kvp in new Dictionary<string, string>() {{"genericHostsCancellationToken", "CancellationToken "}}) {
        var gMethodArgument = new GMethodArgument(kvp.Key, kvp.Value);
        gMethodDeclaration.GMethodArguments[gMethodArgument.Philote] = gMethodArgument;
      }

      GMethodBody gMethodBody = new GMethodBody(statementList: new List<string>() {
        "#region create linkedCancellationSource and token",
        "  // Combine the cancellation tokens,so that either can stop this HostedService",
        "  //linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);",
        "  //GenericHostsCancellationToken = genericHostsCancellationToken;",
        " #endregion",
        " #region Register actions with the CancellationToken (s)",
        "  //GenericHostsCancellationToken.Register(() => logger.LogDebug(debugLocalizer[\"{0} {1} GenericHostsCancellationToken has signalled stopping.\"], \"FileSystemToObjectGraphService\", \"StartAsync\"));",
      "  //internalCancellationToken.Register(() => logger.LogDebug(debugLocalizer[\"{0} {1} internalCancellationToken has signalled stopping.\"], \"FileSystemToObjectGraphService\", \"internalCancellationToken\"));",
      "  //linkedCancellationToken.Register(() => logger.LogDebug(debugLocalizer[\"{0} {1} GenericHostsCancellationToken has signalled stopping.\"], \"FileSystemToObjectGraphService\",\"GenericHostsCancellationToken\"));",
      "#endregion",
      "#region register local event handlers with the IHostApplicationLifetime's events",
      "  // Register the methods defined in this class with the three CancellationToken properties found on the IHostApplicationLifetime instance passed to this class in it's .ctor",
      "  hostApplicationLifetime.ApplicationStarted.Register(OnStarted);",
      "  hostApplicationLifetime.ApplicationStopping.Register(OnStopping);",
      "  hostApplicationLifetime.ApplicationStopped.Register(OnStopped);",
      "#endregion",
      "// Wait to be connected to the stdIn observable",
      "//return Task.CompletedTask;"
      });
      GMethod gMethod = new GMethod(gMethodDeclaration, gMethodBody);
      GMethodGroup newgMethodGroup =
        new GMethodGroup(gName: "Start and Stop Async Methods for IHostedService (part of Generic Host)");
      newgMethodGroup.GMethods[gMethod.Philote] = gMethod;
      return newgMethodGroup;
    }
  }
}
