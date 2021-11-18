using System;

using Microsoft.Extensions.Configuration;
using static ATAP.Utilities.Configuration.Extensions;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Testing.Fixture.Serialization {

  public interface ISerializationFixtureSystemTextJson : ISerializationFixture {
  }

  /// <summary>
  /// A Test Fixture that supports Serialization using the SystemTextJson library
  /// The SerializationFixtureSystemTextJson can only be setup one time, before all tests are run
  ///  because JsonSerializerSettings cannot be modified after any Serialization/Deserialization operations have been performed
  /// </summary>
  public partial class SerializationFixtureSystemTextJson : SerializationFixture, ISerializationFixtureSystemTextJson {
     public ISerializerOptionsAbstract Options { get; set; }

    public SerializationFixtureSystemTextJson() : base() {
            // Get the configSections
      var configSections = GetConfigurationSections();
      // Create a configurationRoot and assign it to this fixture
      // Build initial configurationRoot
      // ToDo: Review for a better "environment:Production" string
      var configurationBuilder = ATAPConfigurationBuilderFromConfigurationSections(isProduction: true, ATAP.Utilities.Testing.StringConstants.EnvironmentProductionTest, this.LoadedFromDirectory, this.InitialStartupDirectory, configSections);
      var configurationRoot = configurationBuilder.Build();
      Serializer = (ISerializerConfigurableAbstract)new ATAP.Utilities.Serializer.Shim.SystemTextJson.Serializer(configurationRoot);
    }

    public SerializationFixtureSystemTextJson(IConfigurationRoot configuration) : base(configuration) {
        Serializer = (ISerializerConfigurableAbstract) new ATAP.Utilities.Serializer.Shim.SystemTextJson.Serializer(configuration);
    }

    // public SerializationFixtureSystemTextJson(IConfigurationRoot configuration) : base() {
    //   Kernel.Load(new SerializerInjectionModuleSystemTextJson(configuration: configuration));
    // }
  }
}
