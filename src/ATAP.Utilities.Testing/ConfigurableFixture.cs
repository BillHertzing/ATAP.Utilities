using System;

using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Testing {

  /// <summary>
  /// A Test Fixture Interface that adds storage for a .Net Core IConfiguration root
  /// </summary>
  public interface IConfigurableFixture {
    public ConfigurationRoot GenericTestConfigurationRoot { get; set; }
    public ConfigurationRoot SpecificTestConfigurationRoot { get; set; }
    // The list of environment prefixes this test will recognize
    public string[] GenericTestEnvPrefixes { get; set; }
    public string[] SpecificTestEnvPrefixes { get; set; }
  }

  /// <summary>
  /// A Test Fixture that adds storage for a .Net Core IConfiguration root
  /// </summary>
  public class ConfigurableFixture : SimpleFixture, IConfigurableFixture {
    public ConfigurationRoot GenericTestConfigurationRoot { get; set; }
    public ConfigurationRoot SpecificTestConfigurationRoot { get; set; }

    // The list of environment prefixes this test will recognize
    public string[] GenericTestEnvPrefixes { get; set; } = new string[1] { TestingStringConstants.GenericTestEnvironmentVariablePrefixConfigRootKey };
    public string[] SpecificTestEnvPrefixes { get; set; } = new string[1] { TestingStringConstants.SpecificTestEnvironmentVariablePrefixConfigRootKey };

    public ConfigurableFixture() : base() {
    }

    public void Configure(ConfigurationRoot genericTestConfigurationRoot
    , ConfigurationRoot specificTestConfigurationRoot
    , string[] genericTestEnvPrefixes
    , string[] specificTestEnvPrefixes) {
      GenericTestConfigurationRoot = genericTestConfigurationRoot ?? throw new ArgumentNullException(nameof(genericTestConfigurationRoot));
      SpecificTestConfigurationRoot = specificTestConfigurationRoot ?? throw new ArgumentNullException(nameof(specificTestConfigurationRoot));
      GenericTestEnvPrefixes = genericTestEnvPrefixes ?? throw new ArgumentNullException(nameof(genericTestEnvPrefixes));
      SpecificTestEnvPrefixes = specificTestEnvPrefixes ?? throw new ArgumentNullException(nameof(specificTestEnvPrefixes));
    }
  }
}
