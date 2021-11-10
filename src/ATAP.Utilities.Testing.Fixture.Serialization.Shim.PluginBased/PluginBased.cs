using System;
using System.Collections.Concurrent;
using System.Text.Json;

// ToDo: make a separate assembly for subloading, to be included only if the code will be loaded dynamically
#if NETCORE
using ATAP.Utilities.Loader;
using ATAP.Utilities.FileIO;
using System.Reflection;
#endif


namespace ATAP.Utilities.Testing {

  public interface ISerializationSystemTextJsonFixture {
    public JsonSerializerOptions JsonSerializerOptions { get; set; }

  }
  /// <summary>
  /// A Test Fixture that  that supports Serialization using the SystemTextJson library
    /// The SerializationFixtureSystemTextJson can only be setup one time, before all tests are run
  ///  because JsonSerializerSettings cannot be modified after any Serialization/Deserialization operations have been performed

  /// </summary>
  public partial class SerializationSystemTextJsonFixture : ConfigurableFixture, ISerializationSystemTextJsonFixture {
    public JsonSerializerOptions JsonSerializerOptions { get; set; }

    public SerializationSystemTextJsonFixture() : base() {
      JsonSerializerOptions = new JsonSerializerOptions();
    }
  }
}
