using System.Collections.Generic;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Hosting;
using ATAP.Utilities.ETW;
using Microsoft.Extensions.Localization;
using System.Threading;
using System.IO;

namespace ATAP.Utilities.Extensions.Configuration {
#if TRACE
  [ETWLogAttribute]
#endif
  public static class Extensions {

    public static IConfigurationBuilder StandardConfigurationBuilder(string loadedFromDirectory, string initialStartupDirectory, Dictionary<string, string> defaultConfiguration, string settingsFileName, string settingsFileNameSuffix, string customEnvironmentVariablePrefix, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, CancellationToken externalCancellationToken) {
      ILogger logger = loggerFactory.CreateLogger(nameof(Extensions));
      // IStringLocalizer stringLocalizer = stringLocalizerFactory.Create(nameof(Extensions),".");
      #region Internal and Linked CancellationTokenSource and Tokens
      CancellationTokenSource internalCancellationTokenSource = new CancellationTokenSource();
      CancellationToken internalCancellationToken = internalCancellationTokenSource.Token;
      CancellationTokenSource linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
      int checkpointNumber = 0;
      #region CancellationToken creation and linking
      // Combine the cancellation tokens,so that either can stop this method
      internalCancellationToken = internalCancellationTokenSource.Token;
      linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
      var linkedCancellationToken = linkedCancellationTokenSource.Token;
      #endregion
      #region Register actions with the CancellationToken (s)
      externalCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: externalCancellationToken has signalled stopping."));
      internalCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: internalCancellationToken has signalled stopping."));
      linkedCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: linkedCancellationToken has signalled stopping."));
      #endregion
      #endregion

      #region static helper methods to reduce code clutter
      // Helper methods to reduce code clutter
      void CheckAndHandleCancellationToken(int checkpointNumber, CancellationToken cancellationToken) {
        // check CancellationToken to see if this task is cancelled
        if (cancellationToken.IsCancellationRequested) {
          // ToDo localize the Log message
          logger.LogDebug($"in StandardConfigurationBuilder: Cancellation requested, checkpoint number {checkpointNumber}");
          cancellationToken.ThrowIfCancellationRequested();
        }
      }
      #endregion
      CheckAndHandleCancellationToken(checkpointNumber, linkedCancellationToken);
      // ToDo: Either here, or when acessing a ConfigurationRoot Value - how to best handle a JSON formatting issue in one of the configuration files.
      IConfigurationBuilder configurationBuilder = new ConfigurationBuilder()
      // Start with a "compiled-in defaults" for anything that is REQUIRED to be provided in configuration for Production
      .AddInMemoryCollection(defaultConfiguration);
      // ToDo: setup exception handling, need new exception.
      // ToDo: Not available in Standard, only in Core. see also FileConfigurationExtensions.SetFileLoadExceptionHandler(IConfigurationBuilder, Action<FileLoadExceptionContext>) 
      // SetBasePath creates a Physical File provider pointing to the directory where this assembly was loaded from
      configurationBuilder.SetBasePath(Path.GetFullPath(loadedFromDirectory));
      // get any Production level Settings file present in the installation directory
      CheckAndHandleCancellationToken(checkpointNumber, linkedCancellationToken);
      // ToDo: File names should be localized
      configurationBuilder.AddJsonFile(settingsFileName + "." + settingsFileNameSuffix, optional: true);
      // Add environment-specific settings file
      if (!hostEnvironment.IsProduction()) {
        configurationBuilder.AddJsonFile(settingsFileName + "." + hostEnvironment.EnvironmentName + "." + settingsFileNameSuffix, optional: true);
      }
      CheckAndHandleCancellationToken(checkpointNumber, linkedCancellationToken);
      // and again, SetBasePath creates a Physical File provider, this time pointing to the initial startup directory, which will be used by the following method
      configurationBuilder.SetBasePath(Path.GetFullPath(initialStartupDirectory));
      configurationBuilder.AddJsonFile(settingsFileName + "." + settingsFileNameSuffix, optional: true);
      if (!hostEnvironment.IsProduction()) {
        configurationBuilder.AddJsonFile(settingsFileName + "." + hostEnvironment.EnvironmentName + "." + settingsFileNameSuffix, optional: true);
      }
      CheckAndHandleCancellationToken(checkpointNumber, linkedCancellationToken);
      // Add environment variables, only environment variables that start with the given prefix
      configurationBuilder.AddEnvironmentVariables(prefix: customEnvironmentVariablePrefix);
      // Note that command line arguments are available on hostConfig
      return configurationBuilder;
    }


  }

}
