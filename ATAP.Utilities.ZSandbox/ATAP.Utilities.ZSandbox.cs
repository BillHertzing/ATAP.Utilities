using System;
using Newtonsoft.Json;
using System.Collections.Generic;
using System.Linq;

namespace ATAP.Utilities.ZSandbox {
  // Put this into its own utility project/dll someday
  public static class ObjectUtilities
  {
    public static bool ArePropertiesNotNull<T>(this T obj)
    {
      return typeof(T).GetProperties().All(propertyInfo => propertyInfo.GetValue(obj) != null);
    }
  }
  public static class JSONSerializeAndDeSerializeTupleExamples {
        
        public static(string k1, string k2) DeSerializeSimpleTuple(string _input) {
            return JsonConvert.DeserializeObject<(string k1, string k2)>(_input);
        }

        public static string SerializeSimpleTuple((string k1, string k2) _input) {
            return JsonConvert.SerializeObject(_input);
        }
        public static (string k1, Dictionary<string, double> term1) DeSerializeDictionaryTuple(string _input)
        {
            return JsonConvert.DeserializeObject<(string k1, Dictionary<string, double> term1)>(_input);
        }

        public static string SerializeDictionaryTuple((string k1, Dictionary<string, double> term1) _input)
        {
            return JsonConvert.SerializeObject(_input);
        }
        public static string SerializeReadOnlyDictionaryTuple((string k1, IReadOnlyDictionary<string, double> term1) _input)
        {
            return JsonConvert.SerializeObject(_input);
        }
        public static (string k1, IReadOnlyDictionary<string, double> term1) DeSerializeReadOnlyDictionaryTuple(string _input)
        {
            return JsonConvert.DeserializeObject<(string k1, Dictionary<string, double> term1)>(_input);
        }
        public static string SerializeCollectionOfSimpleTuple(IEnumerable<(string k1, string k2)> _input)
        {
            return JsonConvert.SerializeObject(_input);
        }
        public static IEnumerable<(string k1, string k2)> DeSerializeSingleInputStringFormattedAsJSONCollectionOfSimpleTuples(string _input)
        {
            return JsonConvert.DeserializeObject<IEnumerable<(string k1, string k2)>>(_input);
        }
        public static string SerializeCollectionOfComplexTuple(IEnumerable<(string k1, string k2, IReadOnlyDictionary<string, double> term1)> _input)
        {
            return JsonConvert.SerializeObject(_input);
        }
        public static IEnumerable<(string k1, string k2, IReadOnlyDictionary<string, double> term1)> DeSerializeSingleInputStringFormattedAsJSONCollectionOfComplexTuples(string _input)
        {
            return JsonConvert.DeserializeObject<IEnumerable<(string k1, string k2, IReadOnlyDictionary<string, double> term1)>>(_input);
        }
    }
}
