using System;
using System.Collections.Generic;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Testing;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Testing.Fixture.Serialization {
  public partial class SerializationFixtureSystemTextJson : SerializationFixture, ISerializationFixtureSystemTextJson {

    #region Configuration sections: Traverse the inheritance chain and get the various configurationSections from each
    public new (List<Dictionary<string, string>>, List<(string, string)>, List<string>) GetConfigurationSections() {
      // Traverse the inheritance chain, accumulate the config sections at each level
      // ToDo: Add logger
      (List<Dictionary<string, string>> lDCs, List<(string, string)> lSFTs, List<string> lEVPs) = base.GetConfigurationSections();
      // ToDo: add commandline arguments.
      List<Dictionary<string, string>> DefaultConfigurations = new();
      List<(string, string)> SettingsFiles = new();
      List<string> CustomEnvironmentVariablePrefixs = new();
      DefaultConfigurations.Add(DefaultConfiguration.Production);
      SettingsFiles.Add((StringConstants.SettingsFileName, StringConstants.SettingsFileNameSuffix));
      CustomEnvironmentVariablePrefixs.Add(StringConstants.CustomEnvironmentVariablePrefix);
      // ToDo: localize the debug messages
      // logger.Log.Debug("{0} {1}: DefaultConfigurations: {}  SettingsFiles: {} CustomEnvironmentVariablePrefixs: {}", "ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson", "GetConfigurationSections", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      return (DefaultConfigurations, SettingsFiles, CustomEnvironmentVariablePrefixs);
    }
    #endregion

        //     // Traverse the inheritance chain, accumulate the config sections at each level
        // var configSections = GetConfigurationSections();
        // #region Get the ConfigurationBuilder from the ConfigurationSections
        // // Create the final ConfigurationRoot, taking into account all environments, default values, settings files, and environment variables This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
        // bool isProduction = true; // Initial value
        // string? envNameFromConfiguration = StringConstantsGenericHost.EnvironmentProduction;

        //  ConfigurationBuilder configurationBuilder = (ConfigurationBuilder)GetConfigurationBuilderFromConfigurationSections(configSections);
        // #region Initial ConfigurationRoot
        // ConfigurationBuilder configurationBuilder = (ConfigurationBuilder)ConfigurationExtensions.ATAPStandardConfigurationBuilder(isProduction, envNameFromConfiguration, configSections, loadedFromDirectory, initialStartupDirectory);
        // // Create this program's initial ConfigurationRoot
        // var configurationRoot = configurationBuilder.Build();
        // #endregion

      //   #region (optional) Debugging the Configuration
      //   // for debugging and education, uncomment this region and inspect the two section Lists (using debugger Locals) to see exactly what is in the configuration
      //   //    var sections = configurationRoot.GetChildren();
      //   //    List<IConfigurationSection> sectionsAsListOfIConfigurationSections = new List<IConfigurationSection>();
      //   //    List<ConfigurationSection> sectionsAsListOfConfigurationSections = new List<ConfigurationSection>();
      //   //    foreach (var iSection in sections) sectionsAsListOfIConfigurationSections.Add(iSection);
      //   //    foreach (var iSection in sectionsAsListOfIConfigurationSections) sectionsAsListOfConfigurationSections.Add((ConfigurationSection)iSection);
      //   #endregion

      //   #region Environment determination and validation
      //   // ToDo: Before the genericHost is built, have to use a StringConstant for the string that means "Production", and hope the ConfigurationRoot value for Environment matches the StringConstant
      //   // Determine the environment (Debug, TestingUnit, TestingX, QA, QA1, QA2, ..., Staging, Production) to use from the initialconfigurationRoot
      //   envNameFromConfiguration = configurationRoot.GetValue<string>(StringConstantsGenericHost.EnvironmentConfigRootKey, StringConstantsGenericHost.EnvironmentDefault);
      //   Serilog.Log.Debug("{0} {1}: Initial environment name: {2}", "PluginVAGameAOEII", "GetConfigurationRootFromConfigurationSections", envNameFromConfiguration);

      //   // optional: Validate that the environment provided is one this program understands how to use
      //   // Accepting any string for envNameFromConfiguration might pose a security risk, as it will allow arbitrary files to be loaded into the configuration root
      //   switch (envNameFromConfiguration) {
      //     case StringConstantsGenericHost.EnvironmentDevelopment:
      //       // ToDo: Programmers can add things here
      //       break;
      //     case StringConstantsGenericHost.EnvironmentProduction:
      //       // This is the expected leg for Production environment
      //       break;
      //     default:
      //       // IF you want to accept any environment name as OK, just comment out the following throw
      //       // Keep the throw in here if you want to explicitly disallow any environment other than ones specified in the switch
      //       throw new NotImplementedException($"The Environment {envNameFromConfiguration} is not supported");
      //   };
      //   #endregion

      //   #region final (Environment-aware) configurationBuilder and appConfigurationBuilder
      //   // If the initial configurationRoot specifies the Environment is production, then the configurationRoot is correct  "as-is"
      //   //   but if not, build a 2nd (final) configurationBuilder, this time including environment-specific configuration providers
      //   if (envNameFromConfiguration != StringConstantsGenericHost.EnvironmentProduction) {
      //     // Recreate the ConfigurationBuilder for this overall plugin, this time including environment-specific configuration providers.
      //     Serilog.Log.Debug("{0} {1}: Recreating configurationBuilder for Environment: {2}", "PluginVAGameAOEII", "GetConfigurationRootFromConfigurationSections", envNameFromConfiguration);

      //     configurationBuilder = (ConfigurationBuilder)ConfigurationExtensions.ATAPStandardConfigurationBuilder(isProduction, envNameFromConfiguration, configSections, loadedFromDirectory, initialStartupDirectory);

      //     // Create this program's final ConfigurationRoot from the 2nd (final) configurationBuilder
      //     configurationRoot = configurationBuilder.Build();

      //   }
      //   #endregion
      //   return configurationRoot;
      // }
      // #endregion


  }
}
