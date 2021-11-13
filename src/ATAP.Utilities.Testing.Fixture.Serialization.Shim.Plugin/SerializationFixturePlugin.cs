using System;
using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Serializer;

using ATAP.Utilities.Loader;
using ATAP.Utilities.FileIO;
using System.Reflection;


namespace ATAP.Utilities.Testing {

  public interface ISerializationFixturePlugin {

  }
  /// <summary>
  /// A Test Fixture that supports Serialization using the Plugin library
  /// The SerializationFixturePlugin can only be setup one time, before all tests are run
  ///  because some shims do not allow their options to be modified after any Serialization/Deserialization operations have been performed

  /// </summary>
  public partial class SerializationFixturePlugin : ConfigurableFixture, ISerializationFixturePlugin {
     public ISerializerOptions Options { get; set; }

    public SerializationFixturePlugin() : base() {
    }
  }
}
