using System;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Serializer;
using ATAP.Utilities.Serializer.Shim.SystemTextJson;

namespace ATAP.Utilities.Testing {

  public interface ISerializationFixtureSystemTextJson : IDiFixtureNinject {
  }
  
  /// <summary>
  /// A Test Fixture that supports Serialization using the SystemTextJson library
  /// The SerializationFixtureSystemTextJson can only be setup one time, before all tests are run
  ///  because JsonSerializerSettings cannot be modified after any Serialization/Deserialization operations have been performed
  /// </summary>
  public partial class SerializationFixtureSystemTextJson : DiFixtureNinject, ISerializationFixtureSystemTextJson {
     public ISerializerOptions Options { get; set; }

    public SerializationFixtureSystemTextJson(IConfiguration configuration) : base() {
      Kernel.Load(new SerializerInjectionModuleSystemTextJson(configuration: configuration));
    }
  }
}
