using System;
using System.Collections;
using System.Collections.Generic;

namespace ATAP.Utilities.Serializer {
  public interface ISerializer {
    ISerializerOptions Options { get; set; }
    string Serialize(object obj);
    string Serialize(object obj, ISerializerOptions options);
    T Deserialize<T>(string str);
    T Deserialize<T>(string str, ISerializerOptions options);
    void Configure();
    void Configure(ISerializerOptions options);
  }
}
