using System;
using System.Collections.Generic;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Serializer;
using ATAP.Utilities.Serializer.Shim.SystemTextJson;

using ATAP.Utilities.Testing.Fixture.Serialization;

namespace ATAP.Utilities.Testing {

  public interface ISerializationFixtureSystemTextJson : ISerializationFixture {
  }

  /// <summary>
  /// A Test Fixture that supports Serialization using the SystemTextJson library
  /// The SerializationFixtureSystemTextJson can only be setup one time, before all tests are run
  ///  because JsonSerializerSettings cannot be modified after any Serialization/Deserialization operations have been performed
  /// </summary>
  public partial class SerializationFixtureSystemTextJson : SerializationFixture, ISerializationFixtureSystemTextJson {
     public ISerializerOptions Options { get; set; }

    public SerializationFixtureSystemTextJson() : base() {
      Serializer = (ISerializer)new ATAP.Utilities.Serializer.Shim.SystemTextJson.Serializer();
    }

    // public SerializationFixtureSystemTextJson(IConfigurationRoot configuration) : base(configuration) {
    //         Serializer = (ISerializer) this;
    // }

    // public SerializationFixtureSystemTextJson(IConfigurationRoot configuration) : base() {
    //   Kernel.Load(new SerializerInjectionModuleSystemTextJson(configuration: configuration));
    // }
  }
}
