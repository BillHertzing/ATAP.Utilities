using System;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Testing;

using ATAP.Utilities.Serializer;


namespace ATAP.Utilities.Testing.Fixture.Serialization {

  public interface ISerializationFixture : IConfigurableFixture {
    ISerializerConfigurableAbstract Serializer { get; set; }
  }

  public partial class SerializationFixture : ConfigurableFixture, ISerializationFixture {
    public ISerializerConfigurableAbstract Serializer { get; set; }

    public SerializationFixture() : base() {
    }

    public SerializationFixture(IConfigurationRoot configuration) : base(configuration) {
      // private SerializationFixture(IConfigurationRoot configuration) : base(new ConfigurationRoot()) {
      // ToDo: can't just new up an empty configuration and expect it to work. Configuration is going to set the JSON serializer's library options, and add type converter factories / classes
      // ToDo: Figure out how to get the test runner (xunit) to create an ATAP configurationRoot (use the ATAP generic host extensions) and pass it to this constructor

    }

    private SerializationFixture(ISerializerConfigurableAbstract serializer) : base() {
      if (serializer == null) { throw new ArgumentNullException(nameof(serializer)); }
      Serializer = serializer;
    }
    private SerializationFixture(IConfigurationRoot configuration, ISerializerConfigurableAbstract serializer) : base(configuration) {
      if (configuration == null) { throw new ArgumentNullException(nameof(configuration)); }
      if (serializer == null) { throw new ArgumentNullException(nameof(serializer)); }
      Serializer = serializer;
    }

  }
}
