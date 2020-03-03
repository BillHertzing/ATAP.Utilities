using ATAP.Utilities.Serializer.Interfaces;
using ServiceStack.Text;
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
      return ServiceStack.Text.JsonSerializer.SerializeToString(obj);
    }
    public T Deserialize<T>(string str)
    {
      return ServiceStack.Text.JsonSerializer.DeserializeFromString<T>(str);
    }

    public void Configure()
    {
      JsConfig.TextCase = TextCase.PascalCase;
      JsConfig.TreatEnumAsInteger = true;
      JsConfig.ExcludeDefaultValues = false;
      JsConfig.IncludeNullValues = true;
      //    new EnumSerializerConfigurator()
      //.WithAssemblies(AppDomain.CurrentDomain.GetAssemblies())
      //.WithNamespaceFilter(ns => ns.StartsWith("ATAP"))
      //.Configure();
    }
  }

}
