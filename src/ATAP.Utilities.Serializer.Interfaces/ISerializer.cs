using System;
using System.Collections;
using System.Collections.Generic;


using Microsoft.Extensions.Configuration;


namespace ATAP.Utilities.Serializer {
  public interface ISerializerAbstract {
    ISerializerOptionsAbstract Options { get; set; }
    string Serialize(object obj);
    string Serialize(object obj, ISerializerOptionsAbstract options);
    T Deserialize<T>(string str);
    T Deserialize<T>(string str, ISerializerOptionsAbstract options);
  }
  public interface ISerializerConfigurableAbstract : ISerializerAbstract {
    IConfigurationRoot? ConfigurationRoot { get; set; }
  }

}
