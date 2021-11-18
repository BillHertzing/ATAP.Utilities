

using System;
using System.Collections.Generic;
using Newtonsoft.Json;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Serializer.Shim.Newtonsoft {

  public  class SerializerOptions : SerializerOptionsAbstract  {
    public SerializerOptions() : base(new JsonSerializerSettings()) { }

    public SerializerOptions(JsonSerializerSettings jsonSerializerSettings) : base(jsonSerializerSettings) { }
  }
}
