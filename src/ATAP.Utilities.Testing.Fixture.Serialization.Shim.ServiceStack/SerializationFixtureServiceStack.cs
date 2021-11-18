using System;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Testing {

  public interface ISerializationFixtureServiceStack : IDiFixtureNinject {
  }
  /// <summary>
  /// A Test Fixture that supports Serialization by injecting the ServiceStack libraries as the ISerializerConfigurableAbstract in the DI-based Fixture
  /// </summary>
  public partial class SerializationFixtureServiceStack : DiFixtureNinject, ISerializationFixtureServiceStack {
     public ISerializerOptionsAbstract Options { get; set; }

    public SerializationFixtureServiceStack(IConfiguration configuration) : base() {
      Kernel.Load(new SerializerInjectionModuleServiceStack(configuration: configuration));
    }
  }
}
