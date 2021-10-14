using System.Collections.Generic;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Hosting;
using ATAP.Utilities.ETW;
using Microsoft.Extensions.Localization;
using System.Threading;
using System.IO;
using System.Diagnostics; // breakpoint insertion

namespace ATAP.Utilities.Configuration {
#if TRACE
  [ETWLogAttribute]
#endif
  public static class Extensions {

    //public static IConfigurationBuilder StandardConfigurationBuilder(string loadedFromDirectory, string initialStartupDirectory, Dictionary<string, string> defaultConfiguration, string settingsFileName, string settingsFileNameSuffix, string customEnvironmentVariablePrefix, ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment, IConfiguration hostConfiguration, CancellationToken externalCancellationToken) {
    //  ILogger logger = loggerFactory.CreateLogger(nameof(Extensions));
    //  // IStringLocalizer stringLocalizer = stringLocalizerFactory.Create(nameof(Extensions),".");
    //  #region Internal and Linked CancellationTokenSource and Tokens
    //  CancellationTokenSource internalCancellationTokenSource = new CancellationTokenSource();
    //  CancellationToken internalCancellationToken = internalCancellationTokenSource.Token;
    //  CancellationTokenSource linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
    //  int checkpointNumber = 0;
    //  #region CancellationToken creation and linking
    //  // Combine the cancellation tokens,so that either can stop this method
    //  internalCancellationToken = internalCancellationTokenSource.Token;
    //  linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
    //  var linkedCancellationToken = linkedCancellationTokenSource.Token;
    //  #endregion
    //  #region Register actions with the CancellationToken (s)
    //  externalCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: externalCancellationToken has signalled stopping."));
    //  internalCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: internalCancellationToken has signalled stopping."));
    //  linkedCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: linkedCancellationToken has signalled stopping."));
    //  #endregion
    //  #endregion

    //  #region static helper methods to reduce code clutter
    //  // Helper methods to reduce code clutter
    //  void CheckAndHandleCancellationToken(int checkpointNumber, CancellationToken cancellationToken) {
    //    // check CancellationToken to see if this task is cancelled
    //    if (cancellationToken.IsCancellationRequested) {
    //      // ToDo localize the Log message
    //      logger.LogDebug($"in StandardConfigurationBuilder: Cancellation requested, checkpoint number {checkpointNumber}");
    //      cancellationToken.ThrowIfCancellationRequested();
    //    }
    //  }
    //  #endregion
    //  CheckAndHandleCancellationToken(checkpointNumber, linkedCancellationToken);
    //  // ToDo: Either here, or when acessing a ConfigurationRoot Value - how to best handle a JSON formatting issue in one of the configuration files.
    //  IConfigurationBuilder configurationBuilder = new ConfigurationBuilder()
    //  // Start with a "compiled-in defaults" for anything that is REQUIRED to be provided in configuration for Production
    //  .AddInMemoryCollection(defaultConfiguration);
    //  // ToDo: setup exception handling, need new exception.
    //  // ToDo: Not available in Standard, only in Core. see also FileConfigurationExtensions.SetFileLoadExceptionHandler(IConfigurationBuilder, Action<FileLoadExceptionContext>)
    //  // SetBasePath creates a Physical File provider pointing to the directory where this assembly was loaded from
    //  configurationBuilder.SetBasePath(Path.GetFullPath(loadedFromDirectory));
    //  // get any Production level Settings file present in the installation directory
    //  CheckAndHandleCancellationToken(checkpointNumber, linkedCancellationToken);
    //  // ToDo: File names should be localized
    //  configurationBuilder.AddJsonFile(settingsFileName + "." + settingsFileNameSuffix, optional: true);
    //  // Add environment-specific settings file
    //  if (!hostEnvironment.IsProduction()) {
    //    configurationBuilder.AddJsonFile(settingsFileName + "." + hostEnvironment.EnvironmentName + "." + settingsFileNameSuffix, optional: true);
    //  }
    //  CheckAndHandleCancellationToken(checkpointNumber, linkedCancellationToken);
    //  // and again, SetBasePath creates a Physical File provider, this time pointing to the initial startup directory, which will be used by the following method
    //  configurationBuilder.SetBasePath(Path.GetFullPath(initialStartupDirectory));
    //  configurationBuilder.AddJsonFile(settingsFileName + "." + settingsFileNameSuffix, optional: true);
    //  if (!hostEnvironment.IsProduction()) {
    //    configurationBuilder.AddJsonFile(settingsFileName + "." + hostEnvironment.EnvironmentName + "." + settingsFileNameSuffix, optional: true);
    //  }
    //  CheckAndHandleCancellationToken(checkpointNumber, linkedCancellationToken);
    //  // Add environment variables, only environment variables that start with the given prefix
    //  configurationBuilder.AddEnvironmentVariables(prefix: customEnvironmentVariablePrefix);
    //  // Note that command line arguments are available on hostConfig
    //  return configurationBuilder;
    //}


    /// <summary>
    /// Standard form of a ConfigurationRoot
    /// </summary>
    /// <param name="compiledInConfiguration"></param>
    /// <param name="isProduction"></param>
    /// <param name="envNameFromConfiguration"></param>
    /// <param name="settingsFileName"></param>
    /// <param name="settingsFileNameSuffix"></param>
    /// <param name="loadedFromDirectory"></param>
    /// <param name="initialStartupDirectory"></param>
    /// <param name="envVarPrefixs"></param>
    /// <param name="args"></param>
    /// <returns></returns>
    public static IConfigurationBuilder ATAPStandardConfigurationBuilder(Dictionary<string, string> compiledInConfiguration, bool isProduction, string? envNameFromConfiguration, string settingsFileName, string settingsFileNameSuffix, string loadedFromDirectory, string initialStartupDirectory, IEnumerable<string>? envVarPrefixs, string[]? args, Dictionary<string, string>? switchMappings) {
      IConfigurationBuilder configurationBuilder = new ConfigurationBuilder()
      .AddInMemoryCollection(compiledInConfiguration)
      // SetBasePath creates a Physical File provider pointing to the installation directory, which will be used by the following method
      .SetBasePath(loadedFromDirectory)
      // get any Production level GenericHostSettings file present in the installation directory
      // Todo: File names should be localized
      .AddJsonFile(settingsFileName + settingsFileNameSuffix, optional: true);
      // Add environment-specific settings file
      if (!isProduction) {
        configurationBuilder.AddJsonFile(settingsFileName + "." + envNameFromConfiguration + settingsFileNameSuffix, optional: true);
      };
      // and again, SetBasePath creates a Physical File provider, this time pointing to the initial startup directory, which will be used by the following method
      configurationBuilder.SetBasePath(initialStartupDirectory)
      // get any Production level GenericHostSettings file  present in the initial startup directory
      .AddJsonFile(settingsFileName + settingsFileNameSuffix, optional: true);
      // Add environment-specific settings file
      if (!isProduction) {
        configurationBuilder.AddJsonFile(settingsFileName + "." + envNameFromConfiguration + settingsFileNameSuffix, optional: true);
      };
      // Add environment variables with the prefixs as specified in the Prefixs collection, if specified
      if (envVarPrefixs != null) {
        foreach (var pf in envVarPrefixs) {
          configurationBuilder.AddEnvironmentVariables(prefix: pf);
        }
      }
      // add the command line arguments and any mappings, if specified
      if (args != null) {
        configurationBuilder.AddCommandLine(args);
      }
      // add command line switchMappings, if specifieed
      if (switchMappings != null) {
        configurationBuilder.AddCommandLine(args);
      }
      //
      return configurationBuilder;
    }

    public static IConfigurationBuilder ATAPStandardConfigurationBuilder(bool isProduction, string? envNameFromConfiguration, (List<Dictionary<string, string>> lDCs, List<(string, string)> lSFTs, List<string> lEVPs) configurationTuple, string loadedFromDirectory, string initialStartupDirectory) {
      // ToDo: Parameter null checking, also the tuple elements
      IConfigurationBuilder configurationBuilder = new ConfigurationBuilder();
      foreach (Dictionary<string, string> compiledInConfiguration in configurationTuple.lDCs) {
        configurationBuilder.AddInMemoryCollection(compiledInConfiguration);
      }
      // SetBasePath creates a Physical File provider pointing to the installation directory, which will be used by the following method
      configurationBuilder.SetBasePath(loadedFromDirectory);
      foreach ((string name, string suffix) sFT in configurationTuple.lSFTs) {
        // get any Settings file matching the list in the configurationTuple generated by traversing the inheritance list present in the installation directory
        // Todo: File names should be localized
        configurationBuilder.AddJsonFile(sFT.name + sFT.suffix, optional: true);
        // Add environment-specific settings file
        if (!isProduction) {
          configurationBuilder.AddJsonFile(sFT.name + "." + envNameFromConfiguration + "." + sFT.suffix, optional: true);
        };
      }
      // Add environment variables with the prefixs as specified in the Prefixs collection, if specified
      foreach (string eVP in configurationTuple.lEVPs) {
        configurationBuilder.AddEnvironmentVariables(prefix: eVP);
      }
      return configurationBuilder;
    }

  }
}
