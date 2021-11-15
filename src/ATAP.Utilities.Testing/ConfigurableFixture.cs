using System;

using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Testing {

  /// <summary>
  /// A Test Fixture Interface that adds storage for a .Net Core IConfiguration root
  /// </summary>
  public interface IConfigurableFixture {
    IConfigurationRoot? ConfigurationRoot { get; set; }

    //public IConfigurationRoot? GenericTestConfigurationRoot { get; set; }
    //public IConfigurationRoot? SpecificTestConfigurationRoot { get; set; }
    // The list of environment prefixes this test will recognize
    //string[]? EnvironmentVariablePrefixs { get; set; }
    //public string[] GenericTestEnvPrefixes { get; set; }
    //public string[] SpecificTestEnvPrefixes { get; set; }
  }

  /// <summary>
  /// A Test Fixture that adds storage for a .Net Core IConfiguration root
  /// </summary>
  public partial class ConfigurableFixture : SimpleFixture, IConfigurableFixture {
    public IConfigurationRoot? ConfigurationRoot { get; set; }
    //public IConfigurationRoot? GenericTestConfigurationRoot { get; set; }
    //public IConfigurationRoot? SpecificTestConfigurationRoot { get; set; }

    // The list of environment prefixes this test will recognize
    //public string[]? EnvironmentVariablePrefixs { get; set; }

    //public string[] GenericTestEnvPrefixes { get; set; } = new string[1] { StringConstants.GenericTestEnvironmentVariablePrefixConfigRootKey };
    //public string[] SpecificTestEnvPrefixes { get; set; } = new string[1] { StringConstants.SpecificTestEnvironmentVariablePrefixConfigRootKey };

    public ConfigurableFixture() : base() {
    }
    public ConfigurableFixture(IConfigurationRoot? configurationRoot) : this() {
      ConfigurationRoot = configurationRoot;
    }

    // public ConfigurableFixture(IConfigurationRoot configurationRoot = default
    // //, IConfigurationRoot specificTestConfigurationRoot = default
    // //, string[] genericTestEnvPrefixes = default
    // , string[] environmentVariablePrefixs = default) {
    //   if (configurationRoot != null) { ConfigurationRoot = configurationRoot; }
    //   if (environmentVariablePrefixs != null) { EnvironmentVariablePrefixs = environmentVariablePrefixs; }

    //   // GenericTestConfigurationRoot = genericTestConfigurationRoot ?? throw new ArgumentNullException(nameof(genericTestConfigurationRoot));
    //   // SpecificTestConfigurationRoot = specificTestConfigurationRoot ?? throw new ArgumentNullException(nameof(specificTestConfigurationRoot));
    //   // GenericTestEnvPrefixes = genericTestEnvPrefixes ?? throw new ArgumentNullException(nameof(genericTestEnvPrefixes));
    //   // SpecificTestEnvPrefixes = specificTestEnvPrefixes ?? throw new ArgumentNullException(nameof(specificTestEnvPrefixes));
    // }
  }
}
