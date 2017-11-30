using System;
using Newtonsoft.Json;

namespace ATAP.Utilities.ZSandbox {
    public static class SandboxStatic1 {
        public static (string c1, string c2) x = ("c1", "c2");

        public static(string c1, string c2) DeSerializeTuple(string _input) {
            return JsonConvert.DeserializeObject<(string c1, string c2)>(_input);
        }

        public static string SerializeTuple((string c1, string c2) _input) {
            return JsonConvert.SerializeObject(_input);
        }
    }
}
