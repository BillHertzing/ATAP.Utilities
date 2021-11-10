using System;
using System.Collections.Concurrent;
using System.Text.Json;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Testing {

  public interface ISerializationSystemTextJsonFixture : ISerializer {
  }
  /// <summary>
  /// A Test Fixture that supports Serialization using the SystemTextJson library
  /// The SerializationFixtureSystemTextJson can only be setup one time, before all tests are run
  ///  because JsonSerializerSettings cannot be modified after any Serialization/Deserialization operations have been performed

  /// </summary>
  public partial class SerializationSystemTextJsonFixture : DIFixtureNinject, ISerializationSystemTextJsonFixture {
     public ISerializerOptions Options { get; set; }
    //public JsonSerializerOptions JsonSerializerOptions { get; set; }

    public SerializationSystemTextJsonFixture() : base() {
      JsonSerializerOptions = new JsonSerializerOptions();
    }
  }
}
