using System;
using Microsoft.Extensions.Configuration;
using ServiceStack.Text;

namespace ATAP.Utilities.Serializer.Shim.ServiceStack;

public class Serializer : SerializerConfigurableAbstract
{
  public Serializer()
    : this(new SerializerOptions(), null)
  {
  }

  public Serializer(IConfigurationRoot? configurationRoot)
    : this(new SerializerOptions(), configurationRoot)
  {
  }

  public Serializer(ISerializerOptionsAbstract options)
    : this(options, null)
  {
  }

  public Serializer(
    ISerializerOptionsAbstract options,
    IConfigurationRoot? configurationRoot = default)
    : base(options, configurationRoot)
  {
  }

  public override string Serialize(object obj) =>
    Serialize(obj, Options);

  public override string Serialize(object obj, ISerializerOptionsAbstract options)
  {
    _ = GetConfig(options);
    return JsonSerializer.SerializeToString(obj);
  }

  public override T Deserialize<T>(string str) =>
    Deserialize<T>(str, Options);

  public override T Deserialize<T>(string str, ISerializerOptionsAbstract options)
  {
    _ = GetConfig(options);
    return JsonSerializer.DeserializeFromString<T>(str);
  }

  private static Config GetConfig(ISerializerOptionsAbstract options)
  {
    ArgumentNullException.ThrowIfNull(options);

    return options.ShimSpecificOptions as Config
      ?? throw new ArgumentException(
        "ServiceStack serialization requires ServiceStack.Text.Config options.",
        nameof(options));
  }
}

public class SerializerOptions : SerializerOptionsAbstract
{
  public SerializerOptions()
    : this(CreateDefaultConfig())
  {
  }

  public SerializerOptions(Config config)
    : base(config)
  {
  }

  private static Config CreateDefaultConfig() => new()
  {
    TextCase = TextCase.CamelCase,
    TreatEnumAsInteger = true,
    ExcludeDefaultValues = false,
    IncludeNullValues = true,
    ExcludeTypeInfo = true,
  };
}
