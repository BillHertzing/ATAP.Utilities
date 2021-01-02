

namespace ATAP.Utilities.Serializer.Interfaces {
  public interface ISerializer {
    string Serialize(object obj);
    string Serialize(object obj, ISerializerOptions options);
    T Deserialize<T>(string str);
    T Deserialize<T>(string str, ISerializerOptions options);
    void Configure();
    void Configure(ISerializerOptions options);
    void Configure(
      bool AllowTrailingCommas = false
      ,bool WriteIndented = false
      ,bool IgnoreNullValues = false
      );
  }

  public interface ISerializerOptions {
    bool AllowTrailingCommas { get; set; }
    bool WriteIndented { get; set; }
    bool IgnoreNullValues { get; set; }
  }

}
