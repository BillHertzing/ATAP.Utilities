using System;
using Microsoft.Extensions.Configuration;
using TestingExtensions = ATAP.Utilities.Testing.Extensions;

namespace ATAP.Utilities.Testing {

  /// <summary>
  /// A Test Fixture Interface that adds storage for a .Net Core IConfiguration root
  /// </summary>
  public interface IConfigurableFixture {
public ConfigurationRoot ConfigurationRoot { get; set; }
  }
  /// <summary>
  /// A Test Fixture that adds storage for a .Net Core IConfiguration root
  /// </summary>
  public  class ConfigurableFixture : SimpleFixture, IConfigurableFixture {
    public ConfigurationRoot ConfigurationRoot { get; set; }

    public ConfigurableFixture() : base() { }

    public void Configure (ConfigurationRoot configurationRoot) {
      ConfigurationRoot = configurationRoot ?? throw new ArgumentNullException(nameof(configurationRoot));
    }
  }
}
