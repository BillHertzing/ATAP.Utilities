using System;
using System.Collections.Generic;
using System.Reflection;
using System.Linq;

namespace ATAP.Utilities.Serializer {
  public class SerializerOptions : ISerializerOptions {
    public bool AllowTrailingCommas { get; set; }
    public bool WriteIndented { get; set; }
    public bool IgnoreNullValues { get; set; }

  }
}

