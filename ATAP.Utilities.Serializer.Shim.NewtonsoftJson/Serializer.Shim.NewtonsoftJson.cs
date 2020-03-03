using ATAP.Utilities.Serializer.Interfaces;
using Newtonsoft.Json;
using System;

namespace ATAP.Utilities.Serializer
{
  public class SerializerServiceStackJSON : ISerializer
  {
    //JsonSerializerOptions JsonSerializerOptions { get; private set; }
    public SerializerServiceStackJSON()
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
      // ToDo: newtonsoft configuration for PascalCase
      // ToDo: newtonsoft configuration for Enumerations using Value (int)
      // ToDo: newtonsoft configuration to ensure default values are added to teh serialization (?maybe?)
    }
  }
}
