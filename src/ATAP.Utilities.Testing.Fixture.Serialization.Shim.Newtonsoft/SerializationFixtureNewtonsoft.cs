using System;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Serializer;
using ATAP.Utilities.Serializer.Shim.Newtonsoft;

using ATAP.Utilities.Testing.Fixture.Serialization;

namespace ATAP.Utilities.Testing {
  public interface ISerializationFixtureNewtonsoft : ISerializationFixture {
  }

  /// <summary>
  /// A Test Fixture that supports Serialization using the Newtonsoft library
  /// </summary>
  public partial class SerializationFixtureNewtonsoft : SerializationFixture, ISerializationFixtureNewtonsoft {
     public ISerializerOptions Options { get; set; }

    public SerializationFixtureNewtonsoft() : base() {
          Serializer = (ISerializer)new ATAP.Utilities.Serializer.Shim.Newtonsoft.Serializer();
    }

    // public SerializationFixtureNewtonsoft(IConfigurationRoot configuration) : base(configuration) {
    //         Serializer = (ISerializer) this;
    // }

    // public SerializationFixtureNewtonsoft(IConfigurationRoot configuration) : base() {
    //   Kernel.Load(new SerializerInjectionModuleSystemTextJson(configuration: configuration));
    // }
  }
}
