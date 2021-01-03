using Newtonsoft.Json;
using System;

namespace ATAP.Utilities.Serializer
{
  public class Serializer : ISerializer
  {
    //JsonSerializerOptions JsonSerializerOptions { get; private set; }
    public Serializer()
    {
      this.Configure();
    }

    public string Serialize(object obj)
    {
      return Newtonsoft.Json.JsonConvert.SerializeObject(obj);
    }
    public T Deserialize<T>(string str)
    {
      return Newtonsoft.Json.JsonConvert.DeserializeObject<T>(str);
    }

    public void Configure()
    {
      JsonSerializerSettings S = new Newtonsoft.Json.JsonSerializerSettings();// Func<JsonSerializerSettings>
      var str = "debug";
      // ToDo: newtonsoft configuration for PascalCase
      // ToDo: newtonsoft configuration for Enumerations using Value (int)
      // ToDo: newtonsoft configuration to ensure default values are added to teh serialization (?maybe?)
    }
  }
}
