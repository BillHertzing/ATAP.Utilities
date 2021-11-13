using System;
using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Testing.Fixture.Serialization.Shim.Newtonsoft {

  public interface ISerializationFixtureNewtonsoft : IDiFixtureNinject {
  }
  /// <summary>
  /// A Test Fixture that supports Serialization using the Newtonsoft library
  /// </summary>
  public partial class SerializationFixtureNewtonsoft : DiFixtureNinject, ISerializationFixtureNewtonsoft {
     public ISerializerOptions Options { get; set; }

    public SerializationFixtureNewtonsoft(IConfiguration configuration) : base() {
      Kernel.Load(new SerializerInjectionModuleNewtonsoft(configuration: configuration));
    }
  }
}
