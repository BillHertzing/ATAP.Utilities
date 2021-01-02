
using ATAP.Utilities.Serializer.Interfaces;
namespace ATAP.Utilities.Serializer {
  public class SerializerOptions : ISerializerOptions {
    public bool AllowTrailingCommas { get; set; }
    public bool WriteIndented { get; set; }
    public bool IgnoreNullValues { get; set; }
  }
}
