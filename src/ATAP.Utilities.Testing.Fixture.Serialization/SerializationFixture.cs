using System;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Testing;

using ATAP.Utilities.Serializer;


namespace ATAP.Utilities.Testing.Fixture.Serialization {

  public interface ISerializationFixture : IConfigurableFixture {
    ISerializer Serializer { get; set; }
  }

  public class SerializationFixture : ConfigurableFixture, ISerializationFixture {
    public ISerializer Serializer { get; set; }

    public SerializationFixture() : base() {
    //   // Traverse the inheritance chain, accumulate the config sections at each level
    //   var configSections = GetConfigurationSections();
    //   #region initial ConfigurationBuilder and ConfigurationRoot
    //   // Create the final ConfigurationRoot, taking into account all environments, default values, settings files, and environment variables This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
    //   ConfigurationRoot configurationRoot = (ConfigurationRoot)GetConfigurationRootFromConfigurationSections(configSections);
    //   #region Initial ConfigurationRoot
    //   ConfigurationBuilder configurationBuilder = (ConfigurationBuilder)ConfigurationExtensions.ATAPStandardConfigurationBuilder(isProduction, envNameFromConfiguration, configSections, loadedFromDirectory, initialStartupDirectory);
    //   // Create this program's initial ConfigurationRoot
    //   var configurationRoot = configurationBuilder.Build();
    //   #endregion

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

    private SerializationFixture(IConfigurationRoot configuration) : base(configuration) {
    // private SerializationFixture(IConfigurationRoot configuration) : base(new ConfigurationRoot()) {
    // ToDo: can't just new up an empty configuration and expect it to work. Configuration is going to set the JSON serializer's library options, and add type converter factories / classes
    // ToDo: Figure out how to get the test runner (xunit) to create an ATAP configurationRoot (use the ATAP generic host extensions) and pass it to this constructor

    }

    private SerializationFixture( ISerializer serializer) : base() {
      if (serializer == null) { throw new ArgumentNullException(nameof(serializer)); }
      Serializer = serializer;
    }
    private SerializationFixture(IConfigurationRoot configuration, ISerializer serializer) : base(configuration) {
      if (configuration == null) { throw new ArgumentNullException(nameof(configuration)); }
      if (serializer == null) { throw new ArgumentNullException(nameof(serializer)); }
      Serializer = serializer;
    }
  }
}
