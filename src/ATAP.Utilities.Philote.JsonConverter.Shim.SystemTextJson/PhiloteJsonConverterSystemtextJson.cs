using ATAP.Utilities.StronglyTypedIDs;

using Itenso.TimePeriod;

using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using ATAP.Utilities.Philote;

// ToDo: Fix broken stuff in the commented out code
namespace ATAP.Utilities.Philote.JsonConverter.SystemTextJson {
  public class PhiloteConverterFactory : JsonConverterFactory {
    private static readonly ConcurrentDictionary<Type, System.Text.Json.Serialization.JsonConverter> Cache = new();
    public override bool CanConvert(Type typeToConvert) {
      // ToDo implement the helper ... return PhiloteHelper.IsPhilote(typeToConvert);
      if (!typeToConvert.IsGenericType) {
        return false;
      }

      // if (typeToConvert.GetGenericTypeDefinition() != typeof(Philote<,>)) {
      //   return false;
      // }

      return typeToConvert.GetGenericArguments()[0].IsEnum;
    }

    public override System.Text.Json.Serialization.JsonConverter CreateConverter(
        Type typeToConvert,
        JsonSerializerOptions options) {
      return Cache.GetOrAdd(typeToConvert, CreateConverter);
    }
    private static System.Text.Json.Serialization.JsonConverter CreateConverter(Type typeToConvert) {
      // if (!PhiloteHelper.IsStronglyTypedId(typeToConvert, out var valueType)) {
      //   throw new InvalidOperationException($"Cannot create converter for '{typeToConvert}'");
      // }

      // var type = typeof(PhiloteJsonConverter<,>).MakeGenericType(typeToConvert, valueType);
      // return (System.Text.Json.Serialization.JsonConverter)Activator.CreateInstance(type);

      // Type keyType = type.GetGenericArguments()[0];
      // Type valueType = type.GetGenericArguments()[1];
      // System.Text.Json.Serialization.JsonConverter converter = (System.Text.Json.Serialization.JsonConverter)Activator.CreateInstance(
      //   typeof(DictionaryEnumConverterInner<,>).MakeGenericType(
      //           new Type[] { keyType, valueType }),
      //       BindingFlags.Instance | BindingFlags.Public,
      //       binder: null,
      //       args: new object[] { options },
      //       culture: null);

      //   return converter;

      return default;
    }
  }
}
