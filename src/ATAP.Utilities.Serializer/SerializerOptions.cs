

using System;
using System.Collections.Generic;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Serializer {
    public abstract class SerializerOptionsAbstract : ISerializerOptionsAbstract {
    public object ShimSpecificOptions { get; set; }
    public SerializerOptionsAbstract(object shimSpecificOptions) {
      if (shimSpecificOptions == null) { throw new ArgumentNullException(nameof(shimSpecificOptions)); }
      ShimSpecificOptions = shimSpecificOptions;
    }
  }


}
