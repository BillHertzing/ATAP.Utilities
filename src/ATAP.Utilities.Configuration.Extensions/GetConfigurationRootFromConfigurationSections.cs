using System;
using System.Collections.Generic;
using System.Text;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Localization;
using ATAP.Utilities.ETW;

namespace ATAP.Utilities.Configuration {
  public static partial class Extensions {

    /// <summary>
    /// Internal helper method that adds settings files for production and environment-specific settings files from a specific directory
    /// </summary>
    /// <param name="configurationBuilder"></param>
    /// <param name="isProduction"></param>
    /// <param name="envName"></param>
    /// <param name="basePath"></param>
    /// <param name="lSFTs"></param>
    /// <returns></returns>
    private static IConfigurationBuilder AddSettingsFiles(this IConfigurationBuilder configurationBuilder, bool isProduction, string envName, string basePath, List<(string, string)> lSFTs) {
      configurationBuilder.SetBasePath(basePath);
      // get any Production level Settings file present in the installation directory
      // Todo: File names should be localized
      // Adding capacity makes the StringBuilder much faster. Concatting filenames greater than the capacity will be much ore expensive ("once")
      // ToDo: Add attribution to "performance wars on string concatentation " blog post
      var sb = new StringBuilder(capacity: 255);
      foreach (var settingsFileTuple in lSFTs) {
        sb.Clear();
        sb.Append(settingsFileTuple.Item1);
        sb.Append(settingsFileTuple.Item2);
        configurationBuilder.AddJsonFile(sb.ToString(), optional: true);
      };
      // Add environment-specific settings file
      if (!isProduction) {
        foreach (var settingsFileTuple in lSFTs) {
          sb.Clear();
          sb.Append(settingsFileTuple.Item1);
          sb.Append(".");
          sb.Append(envName);
          sb.Append(settingsFileTuple.Item1);
          configurationBuilder.AddJsonFile(sb.ToString(), optional: true);
        }
      }
      return configurationBuilder;
    }

    /// <summary>
    /// Create a ConfigurationRootBuilder using a tuple of Lists of configuration sources, usually generated
    ///   by 'walking" the inheritance tree using the GetConfigurationSections method in each tree level
    ///   //ToDo: writer a better summary
    /// </summary>
    /// <param name="isProduction"></param>
    /// <param name="envName"></param>
    /// <param name="loadedFromDirectory"></param>
    /// <param name="initialStartupDirectory"></param>
    /// <param name="configSections"></param>
    /// <returns></returns>
    /// <exception cref="ArgumentNullException"></exception>
    ///
    public static IConfigurationBuilder ATAPConfigurationBuilderFromConfigurationSections(bool isProduction, string envName, string loadedFromDirectory, string initialStartupDirectory, (List<Dictionary<string, string>> lDCs, List<(string, string)> lSFTs, List<string> lEVPs) configSections) {
      // ToDo: expand configsections Tuple to add command line arguments and switchMappings from the hierarchy
      if (envName == null) { throw new ArgumentNullException(nameof(envName)); }
      if (loadedFromDirectory == null) { throw new ArgumentNullException(nameof(loadedFromDirectory)); }
      if (initialStartupDirectory == null) { throw new ArgumentNullException(nameof(initialStartupDirectory)); }
      if (configSections.lDCs == null) { throw new ArgumentNullException(nameof(configSections.lDCs)); }
      if (configSections.lSFTs == null) { throw new ArgumentNullException(nameof(configSections.lSFTs)); }
      if (configSections.lEVPs == null) { throw new ArgumentNullException(nameof(configSections.lEVPs)); }
      IConfigurationBuilder configurationBuilder = new ConfigurationBuilder();
      foreach (var compiledInConfiguration in configSections.lDCs) { configurationBuilder.AddInMemoryCollection(compiledInConfiguration); };
      // add providers for Settings (both production and environment-specific) files present in the installation (loadedFrom) directory
      configurationBuilder.AddSettingsFiles(isProduction, envName, loadedFromDirectory, configSections.lSFTs);
      // add providers for Settings (both production and environment-specific) files present in the startup directory
      configurationBuilder.AddSettingsFiles(isProduction, envName, initialStartupDirectory, configSections.lSFTs);
      foreach (string eVP in configSections.lEVPs) {
        configurationBuilder.AddEnvironmentVariables(prefix: eVP);
      }
      return configurationBuilder;
    }
  }
}
