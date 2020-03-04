using ATAP.Utilities.Serializer.Interfaces;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Serialization;
using System;

namespace ATAP.Utilities.Serializer
{
  public class Serializer : ISerializer
  {
    //JsonSerializerOptions JsonSerializerOptions { get; private set; }
    public Serializer()
    {
    }

    public string Serialize(object obj)
    {
      return JsonConvert.SerializeObject(obj);
    }
    public T Deserialize<T>(string str)
    {
      return JsonConvert.DeserializeObject<T>(str);
    }

    public void Configure()
    {
      // Configure for Newtonsoft
      JsonConvert.DefaultSettings = () => new JsonSerializerSettings
      {
        Converters = {
            new StringEnumConverter {NamingStrategy = new CamelCaseNamingStrategy() }
        }
      };

      // ToDo: newtonsoft configuration for PascalCase
      // ToDo: newtonsoft configuration for Enumerations using Value (int)
      // ToDo: newtonsoft configuration to ensure default values are added to teh serialization (?maybe?)
    }
  }
}
