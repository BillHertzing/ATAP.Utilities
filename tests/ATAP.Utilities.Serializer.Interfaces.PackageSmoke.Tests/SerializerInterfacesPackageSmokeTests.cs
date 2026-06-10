using System;

using ATAP.Utilities.Serializer;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace ATAP.Utilities.Serializer.Interfaces.PackageSmoke.Tests;

public sealed class SerializerInterfacesPackageSmokeTests {
  [Fact]
  public void InterfacesCanBeImplementedFromTheReferencedPackage() {
    var serializer = new SmokeSerializer();

    Assert.IsAssignableFrom<ISerializerAbstract>(serializer);
    Assert.IsAssignableFrom<ISerializerConfigurableAbstract>(serializer);
    Assert.Equal("value", serializer.Serialize("value"));
    Assert.Equal("value", serializer.Deserialize<string>("value"));
  }

  private sealed class SmokeSerializer : ISerializerConfigurableAbstract {
    public ISerializerOptionsAbstract Options { get; set; } = new SmokeSerializerOptions();

    public IConfigurationRoot? ConfigurationRoot { get; set; }

    public string Serialize(object obj) => obj?.ToString() ?? string.Empty;

    public string Serialize(object obj, ISerializerOptionsAbstract options) {
      Options = options;
      return Serialize(obj);
    }

    public T Deserialize<T>(string str) => (T)Convert.ChangeType(str, typeof(T));

    public T Deserialize<T>(string str, ISerializerOptionsAbstract options) {
      Options = options;
      return Deserialize<T>(str);
    }
  }

  private sealed class SmokeSerializerOptions : ISerializerOptionsAbstract {
    public object ShimSpecificOptions { get; set; } = new object();
  }
}
