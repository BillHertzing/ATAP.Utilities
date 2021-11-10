using System;
using System.Collections.Concurrent;
// using System.Text.Json;

namespace ATAP.Utilities.Testing.Fixture.Serialization {

  public interface ISerializationSystemTextJsonFixture {
    //public JsonSerializerOptions JsonSerializerOptions { get; set; }

  }
  /// <summary>
  /// A Test Fixture that  that supports Serialization using the SystemTextJson library
    /// The SerializationFixtureSystemTextJson can only be setup one time, before all tests are run
  ///  because JsonSerializerSettings cannot be modified after any Serialization/Deserialization operations have been performed

  /// </summary>
  public partial class SerializationSystemTextJsonFixture : ConfigurableFixture, ISerializationSystemTextJsonFixture {
    //public JsonSerializerOptions JsonSerializerOptions { get; set; }

    public SerializationSystemTextJsonFixture() : base() {
      JsonSerializerOptions = new JsonSerializerOptions();
    }
  }
}
