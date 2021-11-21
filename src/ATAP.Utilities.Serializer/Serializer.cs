using System;
using System.Collections.Generic;
using System.Reflection;
using System.Linq;

using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Serializer {
  public abstract class SerializerAbstract : ISerializerAbstract {
    public ISerializerOptionsAbstract Options { get; set; }
    public abstract string Serialize(object obj);
    public abstract string Serialize(object obj, ISerializerOptionsAbstract options);
    public abstract T Deserialize<T>(string str);
    public abstract T Deserialize<T>(string str, ISerializerOptionsAbstract options);

    public SerializerAbstract() { }
    public SerializerAbstract(ISerializerOptionsAbstract options) {
      if (options == null) { throw new ArgumentNullException(nameof(options)); }
      Options = options;
    }
  }

  public abstract class SerializerConfigurableAbstract : SerializerAbstract, ISerializerConfigurableAbstract {
    public IConfigurationRoot? ConfigurationRoot { get; set; }
    // public virtual void Configure() { }
    // public virtual void Configure(IConfigurationRoot configurationRoot) {
    //   ConfigurationRoot = configurationRoot;
    // }
    // public virtual void Configure(ISerializerOptionsAbstract options) {
    //   if (options == null) { throw new ArgumentNullException(nameof(options)); }
    //   Options = options;
    // }
    // public virtual void Configure(ISerializerOptionsAbstract options, IConfigurationRoot? configurationRoot) {
    //   Configure(options);
    //   Configure(configurationRoot);
    // }

    //public SerializerConfigurableAbstract() : this(null, null) { }
    public SerializerConfigurableAbstract(ISerializerOptionsAbstract options) : this(options, null) { }
    //public SerializerConfigurableAbstract(IConfigurationRoot? configurationRoot) : this(null, configurationRoot) { }
    public SerializerConfigurableAbstract(ISerializerOptionsAbstract options, IConfigurationRoot? configurationRoot) : base(options) {
      ConfigurationRoot = configurationRoot;
    }
  }
}
