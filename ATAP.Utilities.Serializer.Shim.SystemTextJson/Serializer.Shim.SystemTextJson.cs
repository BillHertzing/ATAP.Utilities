using ATAP.Utilities.Serializer.Interfaces;
using System.Text.Json;

namespace ATAP.Utilities.Serializer
{
  public class Serializer : ISerializer
  {
    public JsonSerializerOptions JsonSerializerOptions { get; private set; }
    public Serializer()
    {
      this.Configure();
    }

    public string Serialize(object obj)
    {
      return JsonSerializer.Serialize(obj, JsonSerializerOptions);
    }
    public T Deserialize<T>(string str)
    {
      return JsonSerializer.Deserialize<T>(str, JsonSerializerOptions);
    }

    public void Configure()
    {
      JsonSerializerOptions = new JsonSerializerOptions
      {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
      };


    }
  }
}
