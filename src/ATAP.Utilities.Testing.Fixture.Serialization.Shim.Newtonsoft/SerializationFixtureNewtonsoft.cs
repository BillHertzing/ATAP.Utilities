using System;

using Microsoft.Extensions.Configuration;
using static ATAP.Utilities.Configuration.Extensions;
using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Testing.Fixture.Serialization {
  public interface ISerializationFixtureNewtonsoft : ISerializationFixture {
  }

  /// <summary>
  /// A Test Fixture that supports Serialization using the Newtonsoft library
  /// </summary>
  public partial class SerializationFixtureNewtonsoft : SerializationFixture, ISerializationFixtureNewtonsoft {
    public ISerializerOptionsAbstract Options { get; set; }

    public SerializationFixtureNewtonsoft() : base() {
      // Get the configSections
      var configSections = GetConfigurationSections();
      // Create a configurationRoot and assign it to this fixture
      // Build initial configurationRoot
      // ToDo: Review for a better "environment:Production" string
      var configurationBuilder = ATAPConfigurationBuilderFromConfigurationSections(isProduction: true, ATAP.Utilities.Testing.StringConstants.EnvironmentProductionTest, this.LoadedFromDirectory, this.InitialStartupDirectory, configSections);
      var configurationRoot = configurationBuilder.Build();
      Serializer = (ISerializerConfigurableAbstract)new ATAP.Utilities.Serializer.Shim.Newtonsoft.Serializer(configurationRoot);
    }

    public SerializationFixtureNewtonsoft(IConfigurationRoot configuration) : base(configuration) {
        Serializer = (ISerializerConfigurableAbstract) new ATAP.Utilities.Serializer.Shim.Newtonsoft.Serializer(configuration);
    }

    // public SerializationFixtureNewtonsoft(IConfigurationRoot configuration) : base() {
    //   Kernel.Load(new SerializerInjectionModuleSystemTextJson(configuration: configuration));
    // }
  }
}
